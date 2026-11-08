import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ftms_constants.dart';
import '../../models/bike_telemetry.dart';
import '../../models/ftms_device.dart';
import '../bluetooth/ble_provider.dart';
import 'indoor_bike_data.dart';

/// FTMS control of the connected trainer.
///
/// Rebuilt only when the Bluetooth link becomes ready or is lost, so that a
/// reconnection gets a fresh notifier (new characteristics, control requested
/// again) while unrelated connection state changes do not reset it.
final ftmsControlProvider =
    StateNotifierProvider<FtmsControlNotifier, FtmsControlState>((ref) {
  final linkReady = ref.watch(
    bleConnectionProvider.select((s) => s.status == ConnectionStatus.ready),
  );
  return FtmsControlNotifier(ref, connected: linkReady);
});

/// Live trainer data stream (merged notifications, see [TelemetryMerger]).
final telemetryStreamProvider = StreamProvider<BikeTelemetry>((ref) {
  return ref.watch(ftmsControlProvider.notifier).telemetryStream;
});

/// Current trainer data. Empty when no trainer is connected or no data arrived.
final currentTelemetryProvider = Provider<BikeTelemetry>((ref) {
  final telemetry = ref.watch(telemetryStreamProvider);
  // After a reconnection the stream provider reloads while keeping the
  // previous value: never show (or record) values from a previous link.
  if (telemetry.isLoading || telemetry.hasError) return BikeTelemetry.empty();
  return telemetry.valueOrNull ?? BikeTelemetry.empty();
});

void _log(String message) {
  if (kDebugMode) debugPrint('[FTMS] $message');
}

String _hex(List<int> bytes) =>
    bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');

/// FTMS Control state
class FtmsControlState {
  const FtmsControlState({
    this.isReady = false,
    this.hasControl = false,
    this.isStarted = false,
    this.currentResistance,
    this.currentTargetPower,
    this.currentGrade,
    this.features,
    this.resistanceRange,
    this.powerRange,
    this.packetsPerSecond = 0,
    this.lastPacketAt,
    this.error,
  });

  /// Commands can be sent (control point found and its indications enabled).
  final bool isReady;
  final bool hasControl;
  final bool isStarted;
  final double? currentResistance;
  final int? currentTargetPower;
  final double? currentGrade;

  /// Capabilities read from the trainer (null until read or if unavailable).
  final FtmsFeatures? features;
  final ResistanceRange? resistanceRange;
  final PowerRange? powerRange;

  /// Indoor Bike Data notifications received during the last second.
  final int packetsPerSecond;
  final DateTime? lastPacketAt;
  final String? error;

  FtmsControlState copyWith({
    bool? isReady,
    bool? hasControl,
    bool? isStarted,
    double? currentResistance,
    int? currentTargetPower,
    double? currentGrade,
    FtmsFeatures? features,
    ResistanceRange? resistanceRange,
    PowerRange? powerRange,
    int? packetsPerSecond,
    DateTime? lastPacketAt,
    String? error,
  }) {
    return FtmsControlState(
      isReady: isReady ?? this.isReady,
      hasControl: hasControl ?? this.hasControl,
      isStarted: isStarted ?? this.isStarted,
      currentResistance: currentResistance ?? this.currentResistance,
      currentTargetPower: currentTargetPower ?? this.currentTargetPower,
      currentGrade: currentGrade ?? this.currentGrade,
      features: features ?? this.features,
      resistanceRange: resistanceRange ?? this.resistanceRange,
      powerRange: powerRange ?? this.powerRange,
      packetsPerSecond: packetsPerSecond ?? this.packetsPerSecond,
      lastPacketAt: lastPacketAt ?? this.lastPacketAt,
      error: error,
    );
  }
}

/// FTMS Control notifier
class FtmsControlNotifier extends StateNotifier<FtmsControlState> {
  FtmsControlNotifier(
    this._ref, {
    required bool connected,
    @visibleForTesting DateTime Function()? clock,
  })  : _connected = connected,
        _clock = clock ?? DateTime.now,
        super(const FtmsControlState()) {
    _init();
  }

  static const _responseTimeout = Duration(seconds: 4);

  final Ref _ref;
  final bool _connected;
  final DateTime Function() _clock;

  BluetoothCharacteristic? _controlPoint;
  BluetoothCharacteristic? _indoorBikeData;
  BluetoothCharacteristic? _machineStatus;
  BluetoothCharacteristic? _fitnessMachineFeature;
  BluetoothCharacteristic? _supportedResistanceRange;
  BluetoothCharacteristic? _supportedPowerRange;

  final List<StreamSubscription<List<int>>> _subscriptions = [];
  final _telemetryController = StreamController<BikeTelemetry>.broadcast();
  final _merger = TelemetryMerger();
  BikeTelemetry? _lastEmitted;
  Timer? _healthTimer;
  int _packetsThisSecond = 0;

  final _ready = Completer<bool>();

  // Control Point commands are serialized: one in flight at a time.
  final _queue = <_FtmsCommand>[];
  _FtmsCommand? _current;
  Future<FtmsResponse>? _controlRequest;
  bool _resistanceAsUint8 = false;

  Stream<BikeTelemetry> get telemetryStream => _telemetryController.stream;

  /// Completes with true once commands can be sent, false if they never can.
  Future<bool> get ready => _ready.future;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    if (!_connected) {
      _markReady(false);
      return;
    }

    final services = _ref.read(bleConnectionProvider.notifier).services;
    BluetoothService? ftmsService;
    for (final s in services ?? const <BluetoothService>[]) {
      if (s.uuid == FtmsConstants.serviceUuid) ftmsService = s;
    }
    if (ftmsService == null) {
      _log('FTMS service not found');
      _markReady(false);
      if (mounted) {
        state =
            state.copyWith(error: 'Service FTMS introuvable sur cet appareil');
      }
      return;
    }

    for (final char in ftmsService.characteristics) {
      final uuid = char.uuid;
      if (uuid == FtmsConstants.controlPoint) {
        _controlPoint = char;
      } else if (uuid == FtmsConstants.indoorBikeData) {
        _indoorBikeData = char;
      } else if (uuid == FtmsConstants.machineStatus) {
        _machineStatus = char;
      } else if (uuid == FtmsConstants.fitnessMachineFeature) {
        _fitnessMachineFeature = char;
      } else if (uuid == FtmsConstants.supportedResistanceRange) {
        _supportedResistanceRange = char;
      } else if (uuid == FtmsConstants.supportedPowerRange) {
        _supportedPowerRange = char;
      }
    }
    _log('characteristics: control point ${_controlPoint != null}, '
        'bike data ${_indoorBikeData != null}, status ${_machineStatus != null}');

    try {
      // 1. Control point indications first. The trainer answers a command only
      //    when they are enabled (FTMS §4.16.1), so commands wait for this step.
      final controlPoint = _controlPoint;
      if (controlPoint != null) {
        await _subscribe(controlPoint, _handleControlPointResponse);
      }
      if (!mounted) return;
      _markReady(controlPoint != null);

      // 2. Live data and machine status.
      final bikeData = _indoorBikeData;
      if (bikeData != null) {
        await _subscribe(bikeData, _handleTelemetryData);
        if (!mounted) return;
      }
      final status = _machineStatus;
      if (status != null) await _subscribe(status, _handleStatusChange);

      // 3. Capabilities: supported targets and ranges.
      await _readDeviceFeatures();
    } catch (e) {
      _log('init error: $e');
      _markReady(false);
      if (mounted) {
        state = state.copyWith(
            error: 'Initialisation du home trainer impossible : $e');
      }
    }
  }

  /// Listens to [char] then enables its notifications/indications, retrying a
  /// few times because GATT operations can fail transiently right after a
  /// connection.
  Future<void> _subscribe(
    BluetoothCharacteristic char,
    void Function(List<int>) onValue,
  ) async {
    if (!mounted) return;
    _subscriptions.add(char.onValueReceived.listen(onValue));
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await char.setNotifyValue(true);
        return;
      } catch (e) {
        lastError = e;
        _log('setNotifyValue(${char.uuid}) attempt $attempt failed: $e');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
      }
    }
    throw lastError!;
  }

  void _markReady(bool ok) {
    if (_ready.isCompleted) return;
    _ready.complete(ok);
    if (mounted) state = state.copyWith(isReady: ok);
  }

  /// Reads the Fitness Machine Feature and the supported ranges.
  Future<void> _readDeviceFeatures() async {
    FtmsFeatures? features;
    ResistanceRange? resistanceRange;
    PowerRange? powerRange;

    final featureChar = _fitnessMachineFeature;
    if (featureChar != null) {
      try {
        final value = await featureChar.read();
        _log('Fitness Machine Feature raw: ${_hex(value)}');
        if (value.length >= 8) {
          final f =
              value[0] | (value[1] << 8) | (value[2] << 16) | (value[3] << 24);
          final t =
              value[4] | (value[5] << 8) | (value[6] << 16) | (value[7] << 24);
          features = FtmsFeatures(
            supportsCadence: f & 0x0002 != 0,
            supportsDistance: f & 0x0004 != 0,
            supportsResistance: f & 0x0080 != 0,
            supportsExpendedEnergy: f & 0x0200 != 0,
            supportsHeartRate: f & 0x0400 != 0,
            supportsPower: f & 0x4000 != 0,
            supportsTargetSpeed: t & 0x0001 != 0,
            supportsTargetInclination: t & 0x0002 != 0,
            supportsTargetResistance: t & 0x0004 != 0,
            supportsTargetPower: t & 0x0008 != 0,
            supportsTargetHeartRate: t & 0x0010 != 0,
            supportsSimulation: t & 0x2000 != 0,
            supportsTargetCadence: t & 0x10000 != 0,
          );
          _log('targets: resistance ${features.supportsTargetResistance}, '
              'power ${features.supportsTargetPower}, '
              'simulation ${features.supportsSimulation}');
        }
      } catch (e) {
        _log('feature read error: $e');
      }
    }

    final resistanceChar = _supportedResistanceRange;
    if (resistanceChar != null && mounted) {
      try {
        final value = await resistanceChar.read();
        if (value.length >= 6) {
          final data = ByteData.sublistView(Uint8List.fromList(value));
          resistanceRange = ResistanceRange(
            minimum: data.getInt16(0, Endian.little) * 0.1,
            maximum: data.getInt16(2, Endian.little) * 0.1,
            increment: data.getUint16(4, Endian.little) * 0.1,
          );
          _log('resistance range: ${resistanceRange.minimum} → '
              '${resistanceRange.maximum} (step ${resistanceRange.increment})');
        }
      } catch (e) {
        _log('resistance range read error: $e');
      }
    }

    final powerChar = _supportedPowerRange;
    if (powerChar != null && mounted) {
      try {
        final value = await powerChar.read();
        if (value.length >= 6) {
          final data = ByteData.sublistView(Uint8List.fromList(value));
          powerRange = PowerRange(
            minimum: data.getInt16(0, Endian.little),
            maximum: data.getInt16(2, Endian.little),
            increment: data.getUint16(4, Endian.little),
          );
          _log('power range: ${powerRange.minimum} → ${powerRange.maximum} W');
        }
      } catch (e) {
        _log('power range read error: $e');
      }
    }

    if (!mounted) return;
    state = state.copyWith(
      features: features,
      resistanceRange: resistanceRange,
      powerRange: powerRange,
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Feeds a raw Indoor Bike Data notification, as received from the trainer
  /// (used by tests to check the whole path from bytes to screen).
  @visibleForTesting
  void handleIndoorBikeData(List<int> value) => _handleTelemetryData(value);

  void _handleTelemetryData(List<int> value) {
    final packet = IndoorBikeDataPacket.parse(value);
    if (packet == null || !mounted) return;
    _packetsThisSecond++;
    _healthTimer ??=
        Timer.periodic(const Duration(seconds: 1), (_) => _onHealthTick());
    _emit(_merger.add(packet, _clock()));
  }

  void _emit(BikeTelemetry telemetry) {
    if (_telemetryController.isClosed) return;
    _lastEmitted = telemetry;
    _telemetryController.add(telemetry);
  }

  /// Once per second: publishes the data rate and expires values that stopped
  /// arriving, so the screen never keeps showing frozen numbers.
  void _onHealthTick() {
    if (!mounted) return;
    final current = _merger.current(_clock());
    if (current != _lastEmitted) _emit(current);
    final rate = _packetsThisSecond;
    _packetsThisSecond = 0;
    if (rate != state.packetsPerSecond ||
        _merger.lastPacketAt != state.lastPacketAt) {
      state = state.copyWith(
        packetsPerSecond: rate,
        lastPacketAt: _merger.lastPacketAt,
      );
    }
  }

  void _handleStatusChange(List<int> value) {
    if (value.isEmpty || !mounted) return;
    switch (value[0]) {
      case 0x01: // Reset
      case 0xFF: // Control permission lost
        _log('machine status 0x${value[0].toRadixString(16)}: control lost');
        state = state.copyWith(hasControl: false);
      case 0x02:
        _log('stopped or paused by the user');
      case 0x04:
        _log('started or resumed by the user');
    }
  }

  void _handleControlPointResponse(List<int> value) {
    _log('control point response: ${_hex(value)}');
    if (value.length < 3 || value[0] != FtmsConstants.opCodeResponseCode) {
      return;
    }
    final command = _current;
    if (command == null || command.opCode != value[1]) {
      // Late answer to a command that already timed out: must not be taken as
      // the answer to the command in flight.
      _log('ignored response for opcode 0x${value[1].toRadixString(16)}');
      return;
    }
    _finish(
      command,
      FtmsResponse(
        requestOpCode: value[1],
        resultCode: value[2],
        isSuccess: value[2] == FtmsConstants.resultSuccess,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Requests control of the trainer (always sends the request).
  Future<bool> requestControl() async {
    final response = await _sendCommand([FtmsConstants.opCodeRequestControl]);
    if (mounted) state = state.copyWith(hasControl: response.isSuccess);
    return response.isSuccess;
  }

  Future<FtmsResponse> start() async {
    final response = await _sendControlled([FtmsConstants.opCodeStartOrResume]);
    if (response.isSuccess && mounted) state = state.copyWith(isStarted: true);
    return response;
  }

  Future<FtmsResponse> stop() async {
    final response = await _sendControlled(
        [FtmsConstants.opCodeStopOrPause, FtmsConstants.stopValue]);
    if (response.isSuccess && mounted) state = state.copyWith(isStarted: false);
    return response;
  }

  Future<FtmsResponse> pause() {
    return _sendControlled(
        [FtmsConstants.opCodeStopOrPause, FtmsConstants.pauseValue]);
  }

  /// Target resistance level (resolution 0.1).
  ///
  /// FTMS 1.0 defines this parameter as UINT8, but many trainers expect a
  /// SINT16: the 2-byte form is sent first and the 1-byte form is used when
  /// the trainer rejects it as an invalid parameter.
  Future<FtmsResponse> setResistance(double level) async {
    final raw = (level * 10).round();
    var response = await _sendControlled(_resistanceCommand(raw));
    if (!_resistanceAsUint8 &&
        response.resultCode == FtmsConstants.resultInvalidParameter &&
        raw >= 0 &&
        raw <= 255) {
      _log('resistance rejected as SINT16, retrying as UINT8');
      _resistanceAsUint8 = true;
      response = await _sendControlled(_resistanceCommand(raw));
    }
    if (response.isSuccess && mounted) {
      state = state.copyWith(currentResistance: level);
    }
    return response;
  }

  List<int> _resistanceCommand(int raw) {
    if (_resistanceAsUint8) {
      return [FtmsConstants.opCodeSetTargetResistance, raw.clamp(0, 255)];
    }
    final value = raw.clamp(-32768, 32767);
    return [
      FtmsConstants.opCodeSetTargetResistance,
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];
  }

  /// Target power in watts (ERG mode).
  Future<FtmsResponse> setTargetPower(int watts) async {
    final range = state.powerRange;
    var target = watts;
    if (range != null && range.maximum > range.minimum) {
      target = target.clamp(range.minimum, range.maximum);
    }
    target = target.clamp(0, 32767);
    final response = await _sendControlled([
      FtmsConstants.opCodeSetTargetPower,
      target & 0xFF,
      (target >> 8) & 0xFF,
    ]);
    if (response.isSuccess && mounted) {
      state = state.copyWith(currentTargetPower: target);
    }
    return response;
  }

  /// Indoor bike simulation parameters (SIM mode).
  Future<FtmsResponse> setSimulationParams({
    double windSpeed = FtmsConstants.defaultWindSpeed,
    double grade = FtmsConstants.defaultGrade,
    double crr = FtmsConstants.defaultCrr,
    double cw = FtmsConstants.defaultCw,
  }) async {
    final windValue = (windSpeed * 1000).round().clamp(-32768, 32767);
    final gradeValue = (grade * 100).round().clamp(-32768, 32767);
    final crrValue = (crr * 10000).round().clamp(0, 255);
    final cwValue = (cw * 100).round().clamp(0, 255);
    final response = await _sendControlled([
      FtmsConstants.opCodeSetSimulationParams,
      windValue & 0xFF,
      (windValue >> 8) & 0xFF,
      gradeValue & 0xFF,
      (gradeValue >> 8) & 0xFF,
      crrValue,
      cwValue,
    ]);
    if (response.isSuccess && mounted) {
      state = state.copyWith(currentGrade: grade);
    }
    return response;
  }

  /// Grade in percent (SIM mode).
  Future<FtmsResponse> setGrade(double grade) =>
      setSimulationParams(grade: grade);

  Future<FtmsResponse> reset() async {
    final response = await _sendCommand([FtmsConstants.opCodeReset]);
    if (response.isSuccess && mounted) {
      state = FtmsControlState(
        isReady: state.isReady,
        features: state.features,
        resistanceRange: state.resistanceRange,
        powerRange: state.powerRange,
      );
    }
    return response;
  }

  /// Sends a command that requires control, requesting control first if
  /// needed and once more if the trainer says control was lost.
  Future<FtmsResponse> _sendControlled(List<int> command) async {
    final control = await _ensureControl();
    if (!control.isSuccess) return control;
    var response = await _sendCommand(command);
    if (response.resultCode == FtmsConstants.resultControlNotPermitted &&
        response.failure == FtmsFailure.none) {
      if (mounted) state = state.copyWith(hasControl: false);
      final again = await _ensureControl();
      if (!again.isSuccess) return again;
      response = await _sendCommand(command);
    }
    return response;
  }

  Future<FtmsResponse> _ensureControl() {
    if (state.hasControl) {
      return Future.value(
          const FtmsResponse.success(FtmsConstants.opCodeRequestControl));
    }
    // Concurrent commands share one control request.
    return _controlRequest ??= () async {
      try {
        final response =
            await _sendCommand([FtmsConstants.opCodeRequestControl]);
        if (mounted) state = state.copyWith(hasControl: response.isSuccess);
        return response;
      } finally {
        _controlRequest = null;
      }
    }();
  }

  Future<FtmsResponse> _sendCommand(List<int> bytes) async {
    final ready = await _ready.future;
    if (!ready || !mounted) {
      return FtmsResponse.failed(bytes.first, FtmsFailure.notConnected);
    }
    final command = _FtmsCommand(bytes);
    _queue.add(command);
    _processNextCommand();
    return command.completer.future;
  }

  void _processNextCommand() {
    if (_current != null || _queue.isEmpty || !mounted) return;
    final controlPoint = _controlPoint;
    if (controlPoint == null) {
      for (final command in _queue) {
        command.complete(
            FtmsResponse.failed(command.opCode, FtmsFailure.notConnected));
      }
      _queue.clear();
      return;
    }

    final command = _queue.removeAt(0);
    _current = command;
    _log('→ ${_hex(command.bytes)}');
    controlPoint.write(command.bytes, withoutResponse: false).then(
      (_) {
        if (_current != command) return; // already answered
        command.timer = Timer(_responseTimeout, () {
          if (_current == command) {
            _log('no response to 0x${command.opCode.toRadixString(16)}');
            _finish(command,
                FtmsResponse.failed(command.opCode, FtmsFailure.timeout));
          }
        });
      },
      onError: (Object e) {
        _log('write error: $e');
        if (_current == command) {
          _finish(command,
              FtmsResponse.failed(command.opCode, FtmsFailure.writeError));
        }
      },
    );
  }

  void _finish(_FtmsCommand command, FtmsResponse response) {
    command.complete(response);
    if (_current == command) _current = null;
    _processNextCommand();
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    if (!_ready.isCompleted) _ready.complete(false);
    // Nobody may wait forever for an answer that will never come.
    final pending = [if (_current != null) _current!, ..._queue];
    _current = null;
    _queue.clear();
    for (final command in pending) {
      command.complete(
          FtmsResponse.failed(command.opCode, FtmsFailure.notConnected));
    }
    _telemetryController.close();
    super.dispose();
  }
}

class _FtmsCommand {
  _FtmsCommand(this.bytes);

  final List<int> bytes;
  final completer = Completer<FtmsResponse>();
  Timer? timer;

  int get opCode => bytes.first;

  void complete(FtmsResponse response) {
    timer?.cancel();
    if (!completer.isCompleted) completer.complete(response);
  }
}

/// Why a command failed without an answer from the trainer.
enum FtmsFailure { none, notConnected, timeout, writeError }

class FtmsResponse {
  const FtmsResponse({
    required this.requestOpCode,
    required this.resultCode,
    required this.isSuccess,
    this.failure = FtmsFailure.none,
  });

  const FtmsResponse.success(this.requestOpCode)
      : resultCode = FtmsConstants.resultSuccess,
        isSuccess = true,
        failure = FtmsFailure.none;

  const FtmsResponse.failed(this.requestOpCode, this.failure)
      : resultCode = FtmsConstants.resultOperationFailed,
        isSuccess = false;

  final int requestOpCode;
  final int resultCode;
  final bool isSuccess;
  final FtmsFailure failure;
}
