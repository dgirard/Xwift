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
  BluetoothCharacteristic? _fitnessMachineFeature;
  BluetoothCharacteristic? _supportedResistanceRange;
  BluetoothCharacteristic? _supportedPowerRange;

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
    print('[FTMS] _init() called, isConnected: ${_connectionState.isConnected}');
    if (!_connectionState.isConnected) {
      print('[FTMS] Not connected, skipping init');
      return;
    }

    try {
      final services = _ref.read(bleConnectionProvider.notifier).services;
      if (services == null) {
        print('[FTMS] No services found');
        return;
      }

      print('[FTMS] Looking for FTMS service (${FtmsConstants.serviceUuid})...');
      final ftmsService = services.firstWhere(
        (s) => s.uuid == FtmsConstants.serviceUuid,
        orElse: () => throw Exception('FTMS service not found'),
      );
      print('[FTMS] Found FTMS service');

      // Get characteristics
      print('[FTMS] Scanning ${ftmsService.characteristics.length} characteristics...');
      for (final char in ftmsService.characteristics) {
        if (char.uuid == FtmsConstants.controlPoint) {
          _controlPoint = char;
          print('[FTMS] Found Control Point characteristic');
        } else if (char.uuid == FtmsConstants.indoorBikeData) {
          _indoorBikeData = char;
          print('[FTMS] Found Indoor Bike Data characteristic');
        } else if (char.uuid == FtmsConstants.machineStatus) {
          _machineStatus = char;
          print('[FTMS] Found Machine Status characteristic');
        } else if (char.uuid == FtmsConstants.fitnessMachineFeature) {
          _fitnessMachineFeature = char;
          print('[FTMS] Found Fitness Machine Feature characteristic');
        } else if (char.uuid == FtmsConstants.supportedResistanceRange) {
          _supportedResistanceRange = char;
          print('[FTMS] Found Supported Resistance Range characteristic');
        } else if (char.uuid == FtmsConstants.supportedPowerRange) {
          _supportedPowerRange = char;
          print('[FTMS] Found Supported Power Range characteristic');
        }
      }

      if (_controlPoint == null) {
        print('[FTMS] WARNING: Control Point characteristic NOT found!');
      }

      // Read device features
      await _readDeviceFeatures();

      // Enable notifications
      await _enableNotifications();
      print('[FTMS] Notifications enabled');
    } catch (e) {
      print('[FTMS] Error initializing: $e');
      state = state.copyWith(error: 'Failed to initialize FTMS: $e');
    }
  }

  /// Read device features from Fitness Machine Feature characteristic
  Future<void> _readDeviceFeatures() async {
    if (_fitnessMachineFeature != null) {
      try {
        final value = await _fitnessMachineFeature!.read();
        print('[FTMS] Fitness Machine Feature raw: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');

        if (value.length >= 8) {
          // First 4 bytes: Fitness Machine Features
          final featureFlags = value[0] | (value[1] << 8) | (value[2] << 16) | (value[3] << 24);
          // Next 4 bytes: Target Setting Features
          final targetFlags = value[4] | (value[5] << 8) | (value[6] << 16) | (value[7] << 24);

          print('[FTMS] Feature Flags: 0x${featureFlags.toRadixString(16).padLeft(8, '0')}');
          print('[FTMS] Target Flags: 0x${targetFlags.toRadixString(16).padLeft(8, '0')}');

          // Parse Feature Flags (bits 0-17)
          print('[FTMS] --- SUPPORTED FEATURES ---');
          if (featureFlags & 0x0001 != 0) print('[FTMS]   - Average Speed');
          if (featureFlags & 0x0002 != 0) print('[FTMS]   - Cadence');
          if (featureFlags & 0x0004 != 0) print('[FTMS]   - Total Distance');
          if (featureFlags & 0x0008 != 0) print('[FTMS]   - Inclination');
          if (featureFlags & 0x0010 != 0) print('[FTMS]   - Elevation Gain');
          if (featureFlags & 0x0020 != 0) print('[FTMS]   - Pace');
          if (featureFlags & 0x0040 != 0) print('[FTMS]   - Step Count');
          if (featureFlags & 0x0080 != 0) print('[FTMS]   - Resistance Level');
          if (featureFlags & 0x0100 != 0) print('[FTMS]   - Stride Count');
          if (featureFlags & 0x0200 != 0) print('[FTMS]   - Expended Energy');
          if (featureFlags & 0x0400 != 0) print('[FTMS]   - Heart Rate');
          if (featureFlags & 0x0800 != 0) print('[FTMS]   - Metabolic Equivalent');
          if (featureFlags & 0x1000 != 0) print('[FTMS]   - Elapsed Time');
          if (featureFlags & 0x2000 != 0) print('[FTMS]   - Remaining Time');
          if (featureFlags & 0x4000 != 0) print('[FTMS]   - Power Measurement');
          if (featureFlags & 0x8000 != 0) print('[FTMS]   - Force on Belt');
          if (featureFlags & 0x10000 != 0) print('[FTMS]   - Power Output');

          // Parse Target Setting Features (bits 0-13)
          print('[FTMS] --- TARGET SETTINGS SUPPORTED ---');
          if (targetFlags & 0x0001 != 0) print('[FTMS]   - Speed Target');
          if (targetFlags & 0x0002 != 0) print('[FTMS]   - Inclination Target');
          if (targetFlags & 0x0004 != 0) print('[FTMS]   - Resistance Target');
          if (targetFlags & 0x0008 != 0) print('[FTMS]   - Power Target');
          if (targetFlags & 0x0010 != 0) print('[FTMS]   - Heart Rate Target');
          if (targetFlags & 0x0020 != 0) print('[FTMS]   - Targeted Expended Energy');
          if (targetFlags & 0x0040 != 0) print('[FTMS]   - Targeted Step Number');
          if (targetFlags & 0x0080 != 0) print('[FTMS]   - Targeted Stride Number');
          if (targetFlags & 0x0100 != 0) print('[FTMS]   - Targeted Distance');
          if (targetFlags & 0x0200 != 0) print('[FTMS]   - Targeted Training Time');
          if (targetFlags & 0x0400 != 0) print('[FTMS]   - Targeted Time in 2 HR Zones');
          if (targetFlags & 0x0800 != 0) print('[FTMS]   - Targeted Time in 3 HR Zones');
          if (targetFlags & 0x1000 != 0) print('[FTMS]   - Targeted Time in 5 HR Zones');
          if (targetFlags & 0x2000 != 0) print('[FTMS]   - Indoor Bike Simulation');
          if (targetFlags & 0x4000 != 0) print('[FTMS]   - Wheel Circumference');
          if (targetFlags & 0x8000 != 0) print('[FTMS]   - Spin Down Control');
          if (targetFlags & 0x10000 != 0) print('[FTMS]   - Targeted Cadence');

          // Critical features for grade/resistance control
          final supportsResistanceTarget = (targetFlags & 0x0004) != 0;
          final supportsInclinationTarget = (targetFlags & 0x0002) != 0;
          final supportsSimulation = (targetFlags & 0x2000) != 0;
          final supportsPowerTarget = (targetFlags & 0x0008) != 0;

          print('[FTMS] === SUMMARY ===');
          print('[FTMS] Resistance Target: ${supportsResistanceTarget ? 'YES' : 'NO'}');
          print('[FTMS] Inclination Target: ${supportsInclinationTarget ? 'YES' : 'NO'}');
          print('[FTMS] Indoor Bike Simulation: ${supportsSimulation ? 'YES' : 'NO'}');
          print('[FTMS] Power Target (ERG): ${supportsPowerTarget ? 'YES' : 'NO'}');
        }
      } catch (e) {
        print('[FTMS] Error reading features: $e');
      }
    } else {
      print('[FTMS] Fitness Machine Feature characteristic not available');
    }

    // Read resistance range if available
    if (_supportedResistanceRange != null) {
      try {
        final value = await _supportedResistanceRange!.read();
        print('[FTMS] Resistance Range raw: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        if (value.length >= 6) {
          final data = ByteData.view(Uint8List.fromList(value).buffer);
          final minRes = data.getInt16(0, Endian.little) * 0.1;
          final maxRes = data.getInt16(2, Endian.little) * 0.1;
          final incRes = data.getUint16(4, Endian.little) * 0.1;
          print('[FTMS] Resistance Range: $minRes to $maxRes (increment: $incRes)');
        }
      } catch (e) {
        print('[FTMS] Error reading resistance range: $e');
      }
    }

    // Read power range if available
    if (_supportedPowerRange != null) {
      try {
        final value = await _supportedPowerRange!.read();
        print('[FTMS] Power Range raw: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        if (value.length >= 6) {
          final data = ByteData.view(Uint8List.fromList(value).buffer);
          final minPower = data.getInt16(0, Endian.little);
          final maxPower = data.getInt16(2, Endian.little);
          final incPower = data.getUint16(4, Endian.little);
          print('[FTMS] Power Range: ${minPower}W to ${maxPower}W (increment: ${incPower}W)');
        }
      } catch (e) {
        print('[FTMS] Error reading power range: $e');
      }
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
    print('[FTMS] Control Point response: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    if (value.length < 3) {
      print('[FTMS] Response too short (${value.length} bytes)');
      return;
    }

    final responseCode = value[0];
    final requestOpCode = value[1];
    final resultCode = value[2];

    if (responseCode == FtmsConstants.opCodeResponseCode) {
      final isSuccess = resultCode == FtmsConstants.resultSuccess;
      print('[FTMS] Response for opCode 0x${requestOpCode.toRadixString(16)}: ${isSuccess ? 'SUCCESS' : 'FAILED (code: $resultCode)'}');

      final response = FtmsResponse(
        requestOpCode: requestOpCode,
        resultCode: resultCode,
        isSuccess: isSuccess,
      );

      _currentCommandCompleter?.complete(response);
      _currentCommandCompleter = null;
      _isProcessingCommand = false;
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
    print('[FTMS] requestControl() called');
    final response = await _sendCommand([FtmsConstants.opCodeRequestControl]);
    print('[FTMS] requestControl() response: ${response.isSuccess ? 'SUCCESS' : 'FAILED (code: ${response.resultCode})'}');
    if (response.isSuccess) {
      state = state.copyWith(hasControl: true);
    } else {
      print('[FTMS] WARNING: Failed to acquire control!');
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
    print('[FTMS] setResistance($level) called, hasControl: ${state.hasControl}');
    if (!state.hasControl) {
      print('[FTMS] No control, requesting control first...');
      final acquired = await requestControl();
      if (!acquired) {
        print('[FTMS] Failed to acquire control, cannot set resistance');
        return false;
      }
    }

    // Convert to SINT16 with 0.1 resolution
    final value = (level * 10).round().clamp(-32768, 32767);
    final bytes = [
      FtmsConstants.opCodeSetTargetResistance,
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];

    final response = await _sendCommand(bytes);
    print('[FTMS] setResistance() result: ${response.isSuccess ? 'SUCCESS' : 'FAILED'}');
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
    print('[FTMS] setGrade($grade) called, hasControl: ${state.hasControl}');
    if (!state.hasControl) {
      print('[FTMS] No control, requesting control first...');
      final acquired = await requestControl();
      if (!acquired) {
        print('[FTMS] Failed to acquire control, cannot set grade');
        return false;
      }
    }
    final result = await setSimulationParams(grade: grade);
    print('[FTMS] setGrade() result: ${result ? 'SUCCESS' : 'FAILED'}');
    return result;
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
      print('[FTMS] ERROR: Control Point is NULL - cannot send commands!');
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

    final cmdHex = command.bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
    print('[FTMS] Sending command: $cmdHex');

    _controlPoint!.write(command.bytes, withoutResponse: false).then((_) {
      print('[FTMS] Command written, waiting for response...');
      // Wait for indication response (handled in _handleControlPointResponse)
      // Timeout after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentCommandCompleter == command.completer) {
          print('[FTMS] Command TIMEOUT after 5 seconds');
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
      print('[FTMS] Command write ERROR: $e');
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
