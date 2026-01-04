import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ftms_constants.dart';
import '../../models/bike_telemetry.dart';
import '../bluetooth/ble_provider.dart';

/// FTMS Control provider
final ftmsControlProvider =
    StateNotifierProvider<FtmsControlNotifier, FtmsControlState>((ref) {
  final connectionState = ref.watch(bleConnectionProvider);
  return FtmsControlNotifier(ref, connectionState);
});

/// Telemetry stream provider
final telemetryStreamProvider = StreamProvider<BikeTelemetry>((ref) {
  final ftmsControl = ref.watch(ftmsControlProvider.notifier);
  return ftmsControl.telemetryStream;
});

/// Current telemetry provider
final currentTelemetryProvider = Provider<BikeTelemetry>((ref) {
  final telemetry = ref.watch(telemetryStreamProvider);
  return telemetry.valueOrNull ?? BikeTelemetry.empty();
});

/// FTMS Control state
class FtmsControlState {
  const FtmsControlState({
    this.hasControl = false,
    this.isStarted = false,
    this.currentResistance,
    this.currentTargetPower,
    this.currentGrade,
    this.error,
  });

  final bool hasControl;
  final bool isStarted;
  final double? currentResistance;
  final int? currentTargetPower;
  final double? currentGrade;
  final String? error;

  FtmsControlState copyWith({
    bool? hasControl,
    bool? isStarted,
    double? currentResistance,
    int? currentTargetPower,
    double? currentGrade,
    String? error,
  }) {
    return FtmsControlState(
      hasControl: hasControl ?? this.hasControl,
      isStarted: isStarted ?? this.isStarted,
      currentResistance: currentResistance ?? this.currentResistance,
      currentTargetPower: currentTargetPower ?? this.currentTargetPower,
      currentGrade: currentGrade ?? this.currentGrade,
      error: error,
    );
  }
}

/// FTMS Control notifier
class FtmsControlNotifier extends StateNotifier<FtmsControlState> {
  FtmsControlNotifier(this._ref, this._connectionState)
      : super(const FtmsControlState()) {
    _init();
  }

  final Ref _ref;
  final BleConnectionState _connectionState;

  BluetoothCharacteristic? _controlPoint;
  BluetoothCharacteristic? _indoorBikeData;
  BluetoothCharacteristic? _machineStatus;

  StreamSubscription<List<int>>? _controlPointSubscription;
  StreamSubscription<List<int>>? _telemetrySubscription;
  StreamSubscription<List<int>>? _statusSubscription;

  final _telemetryController = StreamController<BikeTelemetry>.broadcast();
  Stream<BikeTelemetry> get telemetryStream => _telemetryController.stream;

  // Command queue for serializing Control Point writes
  final _commandQueue = <_FtmsCommand>[];
  bool _isProcessingCommand = false;
  Completer<FtmsResponse>? _currentCommandCompleter;

  Future<void> _init() async {
    if (!_connectionState.isConnected) return;

    try {
      final services = _ref.read(bleConnectionProvider.notifier).services;
      if (services == null) return;

      final ftmsService = services.firstWhere(
        (s) => s.uuid == FtmsConstants.serviceUuid,
      );

      // Get characteristics
      for (final char in ftmsService.characteristics) {
        if (char.uuid == FtmsConstants.controlPoint) {
          _controlPoint = char;
        } else if (char.uuid == FtmsConstants.indoorBikeData) {
          _indoorBikeData = char;
        } else if (char.uuid == FtmsConstants.machineStatus) {
          _machineStatus = char;
        }
      }

      // Enable notifications
      await _enableNotifications();
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize FTMS: $e');
    }
  }

  Future<void> _enableNotifications() async {
    // Control Point indications
    if (_controlPoint != null) {
      await _controlPoint!.setNotifyValue(true);
      _controlPointSubscription = _controlPoint!.onValueReceived.listen(
        _handleControlPointResponse,
      );
    }

    // Indoor Bike Data notifications
    if (_indoorBikeData != null) {
      await _indoorBikeData!.setNotifyValue(true);
      _telemetrySubscription = _indoorBikeData!.onValueReceived.listen(
        _handleTelemetryData,
      );
    }

    // Machine Status notifications
    if (_machineStatus != null) {
      await _machineStatus!.setNotifyValue(true);
      _statusSubscription = _machineStatus!.onValueReceived.listen(
        _handleStatusChange,
      );
    }
  }

  void _handleControlPointResponse(List<int> value) {
    if (value.length < 3) return;

    final responseCode = value[0];
    final requestOpCode = value[1];
    final resultCode = value[2];

    if (responseCode == FtmsConstants.opCodeResponseCode) {
      final response = FtmsResponse(
        requestOpCode: requestOpCode,
        resultCode: resultCode,
        isSuccess: resultCode == FtmsConstants.resultSuccess,
      );

      _currentCommandCompleter?.complete(response);
      _currentCommandCompleter = null;
      _processNextCommand();
    }
  }

  void _handleTelemetryData(List<int> value) {
    final telemetry = _parseTelemetry(value);
    _telemetryController.add(telemetry);
  }

  void _handleStatusChange(List<int> value) {
    // Handle machine status changes (e.g., pause, stop)
    // For now, just log it
  }

  BikeTelemetry _parseTelemetry(List<int> value) {
    if (value.length < 2) return BikeTelemetry.empty();

    final data = ByteData.view(Uint8List.fromList(value).buffer);
    final flags = data.getUint16(0, Endian.little);

    int offset = 2;
    int? instantSpeed;
    int? averageSpeed;
    double? instantCadence;
    double? averageCadence;
    int? totalDistance;
    int? resistanceLevel;
    int? instantPower;
    int? averagePower;
    int? totalEnergy;
    int? heartRate;

    // Parse based on flags bitmap
    // Bit 0: More Data (not present = instant speed present)
    if ((flags & 0x0001) == 0 && offset + 2 <= value.length) {
      instantSpeed = data.getUint16(offset, Endian.little);
      offset += 2;
    }

    // Bit 1: Average Speed present
    if ((flags & 0x0002) != 0 && offset + 2 <= value.length) {
      averageSpeed = data.getUint16(offset, Endian.little);
      offset += 2;
    }

    // Bit 2: Instantaneous Cadence present
    if ((flags & 0x0004) != 0 && offset + 2 <= value.length) {
      final raw = data.getUint16(offset, Endian.little);
      instantCadence = raw * 0.5; // Resolution 0.5
      offset += 2;
    }

    // Bit 3: Average Cadence present
    if ((flags & 0x0008) != 0 && offset + 2 <= value.length) {
      final raw = data.getUint16(offset, Endian.little);
      averageCadence = raw * 0.5;
      offset += 2;
    }

    // Bit 4: Total Distance present (24-bit)
    if ((flags & 0x0010) != 0 && offset + 3 <= value.length) {
      totalDistance = value[offset] |
          (value[offset + 1] << 8) |
          (value[offset + 2] << 16);
      offset += 3;
    }

    // Bit 5: Resistance Level present
    if ((flags & 0x0020) != 0 && offset + 2 <= value.length) {
      resistanceLevel = data.getInt16(offset, Endian.little);
      offset += 2;
    }

    // Bit 6: Instantaneous Power present
    if ((flags & 0x0040) != 0 && offset + 2 <= value.length) {
      instantPower = data.getInt16(offset, Endian.little);
      offset += 2;
    }

    // Bit 7: Average Power present
    if ((flags & 0x0080) != 0 && offset + 2 <= value.length) {
      averagePower = data.getInt16(offset, Endian.little);
      offset += 2;
    }

    // Bit 8: Expended Energy present
    if ((flags & 0x0100) != 0 && offset + 2 <= value.length) {
      totalEnergy = data.getUint16(offset, Endian.little);
      offset += 2;
      // Skip energy per hour and per minute
      offset += 2; // Energy per hour
      offset += 1; // Energy per minute
    }

    // Bit 9: Heart Rate present
    if ((flags & 0x0200) != 0 && offset + 1 <= value.length) {
      heartRate = value[offset];
      offset += 1;
    }

    return BikeTelemetry(
      instantPower: instantPower,
      averagePower: averagePower,
      instantCadence: instantCadence,
      averageCadence: averageCadence,
      instantSpeed: instantSpeed != null ? instantSpeed * 0.01 : null,
      averageSpeed: averageSpeed != null ? averageSpeed * 0.01 : null,
      heartRate: heartRate,
      totalDistance: totalDistance,
      totalEnergy: totalEnergy,
      resistanceLevel: resistanceLevel,
      timestamp: DateTime.now(),
    );
  }

  /// Request control of the fitness machine
  Future<bool> requestControl() async {
    final response = await _sendCommand([FtmsConstants.opCodeRequestControl]);
    if (response.isSuccess) {
      state = state.copyWith(hasControl: true);
    }
    return response.isSuccess;
  }

  /// Start or resume the workout
  Future<bool> start() async {
    if (!state.hasControl) {
      await requestControl();
    }

    final response = await _sendCommand([FtmsConstants.opCodeStartOrResume]);
    if (response.isSuccess) {
      state = state.copyWith(isStarted: true);
    }
    return response.isSuccess;
  }

  /// Stop the workout
  Future<bool> stop() async {
    final response = await _sendCommand([
      FtmsConstants.opCodeStopOrPause,
      FtmsConstants.stopValue,
    ]);
    if (response.isSuccess) {
      state = state.copyWith(isStarted: false);
    }
    return response.isSuccess;
  }

  /// Pause the workout
  Future<bool> pause() async {
    final response = await _sendCommand([
      FtmsConstants.opCodeStopOrPause,
      FtmsConstants.pauseValue,
    ]);
    return response.isSuccess;
  }

  /// Set target resistance level (0-100)
  Future<bool> setResistance(double level) async {
    // Convert to SINT16 with 0.1 resolution
    final value = (level * 10).round().clamp(-32768, 32767);
    final bytes = [
      FtmsConstants.opCodeSetTargetResistance,
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];

    final response = await _sendCommand(bytes);
    if (response.isSuccess) {
      state = state.copyWith(currentResistance: level);
    }
    return response.isSuccess;
  }

  /// Set target power in watts (ERG mode)
  Future<bool> setTargetPower(int watts) async {
    final clamped = watts.clamp(0, 65535);
    final bytes = [
      FtmsConstants.opCodeSetTargetPower,
      clamped & 0xFF,
      (clamped >> 8) & 0xFF,
    ];

    final response = await _sendCommand(bytes);
    if (response.isSuccess) {
      state = state.copyWith(currentTargetPower: clamped);
    }
    return response.isSuccess;
  }

  /// Set simulation parameters (SIM mode)
  Future<bool> setSimulationParams({
    double windSpeed = FtmsConstants.defaultWindSpeed,
    double grade = FtmsConstants.defaultGrade,
    double crr = FtmsConstants.defaultCrr,
    double cw = FtmsConstants.defaultCw,
  }) async {
    // Wind speed: SINT16, resolution 0.001 m/s
    final windValue = (windSpeed * 1000).round().clamp(-32768, 32767);

    // Grade: SINT16, resolution 0.01%
    final gradeValue = (grade * 100).round().clamp(-32768, 32767);

    // CRR: UINT8, resolution 0.0001
    final crrValue = (crr * 10000).round().clamp(0, 255);

    // CW: UINT8, resolution 0.01 kg/m
    final cwValue = (cw * 100).round().clamp(0, 255);

    final bytes = [
      FtmsConstants.opCodeSetSimulationParams,
      windValue & 0xFF,
      (windValue >> 8) & 0xFF,
      gradeValue & 0xFF,
      (gradeValue >> 8) & 0xFF,
      crrValue,
      cwValue,
    ];

    final response = await _sendCommand(bytes);
    if (response.isSuccess) {
      state = state.copyWith(currentGrade: grade);
    }
    return response.isSuccess;
  }

  /// Set grade (convenience method for SIM mode)
  Future<bool> setGrade(double grade) async {
    return setSimulationParams(grade: grade);
  }

  /// Reset the fitness machine
  Future<bool> reset() async {
    final response = await _sendCommand([FtmsConstants.opCodeReset]);
    if (response.isSuccess) {
      state = const FtmsControlState();
    }
    return response.isSuccess;
  }

  Future<FtmsResponse> _sendCommand(List<int> command) async {
    final ftmsCommand = _FtmsCommand(command);
    _commandQueue.add(ftmsCommand);
    _processNextCommand();
    return ftmsCommand.completer.future;
  }

  void _processNextCommand() {
    if (_isProcessingCommand || _commandQueue.isEmpty) return;
    if (_controlPoint == null) {
      // Complete all pending commands with error
      for (final cmd in _commandQueue) {
        cmd.completer.complete(const FtmsResponse(
          requestOpCode: 0,
          resultCode: FtmsConstants.resultOperationFailed,
          isSuccess: false,
        ));
      }
      _commandQueue.clear();
      return;
    }

    _isProcessingCommand = true;
    final command = _commandQueue.removeAt(0);
    _currentCommandCompleter = command.completer;

    _controlPoint!.write(command.bytes, withoutResponse: false).then((_) {
      // Wait for indication response (handled in _handleControlPointResponse)
      // Timeout after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentCommandCompleter == command.completer) {
          command.completer.complete(const FtmsResponse(
            requestOpCode: 0,
            resultCode: FtmsConstants.resultOperationFailed,
            isSuccess: false,
          ));
          _currentCommandCompleter = null;
          _isProcessingCommand = false;
          _processNextCommand();
        }
      });
    }).catchError((e) {
      command.completer.complete(const FtmsResponse(
        requestOpCode: 0,
        resultCode: FtmsConstants.resultOperationFailed,
        isSuccess: false,
      ));
      _isProcessingCommand = false;
      _processNextCommand();
    });
  }

  @override
  void dispose() {
    _controlPointSubscription?.cancel();
    _telemetrySubscription?.cancel();
    _statusSubscription?.cancel();
    _telemetryController.close();
    super.dispose();
  }
}

class _FtmsCommand {
  _FtmsCommand(this.bytes);
  final List<int> bytes;
  final Completer<FtmsResponse> completer = Completer();
}

class FtmsResponse {
  const FtmsResponse({
    required this.requestOpCode,
    required this.resultCode,
    required this.isSuccess,
  });

  final int requestOpCode;
  final int resultCode;
  final bool isSuccess;
}
