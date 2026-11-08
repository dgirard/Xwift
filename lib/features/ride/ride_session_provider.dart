import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_provider.dart';
import '../../models/bike_telemetry.dart';
import '../../models/ride_session.dart';
import '../../models/workout_plan.dart';
import '../control/trainer_control_provider.dart';
import '../ftms/ftms_provider.dart';
import '../heart_rate/hr_monitor_provider.dart';

enum RideStatus { idle, recording, paused }

class RideSessionState {
  const RideSessionState({
    this.status = RideStatus.idle,
    this.startTime,
    this.elapsed = Duration.zero,
    this.distance = 0,
    this.sampleCount = 0,
  });

  final RideStatus status;
  final DateTime? startTime;

  /// Riding time, pauses excluded.
  final Duration elapsed;

  /// Distance since the start of the ride, in meters.
  final int distance;
  final int sampleCount;

  bool get isActive => status != RideStatus.idle;
  bool get isRecording => status == RideStatus.recording;
  bool get isPaused => status == RideStatus.paused;

  RideSessionState copyWith({
    RideStatus? status,
    Duration? elapsed,
    int? distance,
    int? sampleCount,
  }) {
    return RideSessionState(
      status: status ?? this.status,
      startTime: startTime,
      elapsed: elapsed ?? this.elapsed,
      distance: distance ?? this.distance,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }
}

/// The ride being recorded.
///
/// Independent from the screens: leaving the ride screen (profile, history…)
/// does not stop or lose the ride. Works without a trainer: the time, and the
/// heart rate when a monitor is connected, are still recorded.
final rideSessionProvider =
    StateNotifierProvider<RideSessionNotifier, RideSessionState>((ref) {
  return RideSessionNotifier(ref);
});

class RideSessionNotifier extends StateNotifier<RideSessionState> {
  RideSessionNotifier(this._ref, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const RideSessionState());

  final Ref _ref;
  final DateTime Function() _clock;
  final Stopwatch _stopwatch = Stopwatch();
  final List<TelemetrySample> _samples = [];
  Timer? _ticker;
  String? _rideId;
  WorkoutPlan? _programUsed;

  // Trainer counters (distance, energy) are cumulative since the trainer was
  // switched on: the ride keeps the part ridden since its own start.
  final _distance = _CounterBaseline();
  final _energy = _CounterBaseline();

  List<TelemetrySample> get samples => List.unmodifiable(_samples);

  Future<void> start() async {
    if (state.isActive) return;
    _rideId = const Uuid().v4();
    _samples.clear();
    _distance.reset();
    _energy.reset();
    _programUsed = null;
    _stopwatch
      ..reset()
      ..start();
    state = RideSessionState(status: RideStatus.recording, startTime: _clock());
    _startTicker();
    await _ref.read(trainerControlProvider.notifier).onRideStarted();
  }

  Future<void> pause() async {
    if (!state.isRecording) return;
    _stopwatch.stop();
    _ticker?.cancel();
    state =
        state.copyWith(status: RideStatus.paused, elapsed: _stopwatch.elapsed);
    await _ref.read(trainerControlProvider.notifier).onRidePaused();
  }

  Future<void> resume() async {
    if (!state.isPaused) return;
    _stopwatch.start();
    _startTicker();
    state = state.copyWith(status: RideStatus.recording);
    await _ref
        .read(trainerControlProvider.notifier)
        .onRideResumed(_stopwatch.elapsed);
  }

  /// The ride as it would be saved now.
  RideSession buildSession() {
    final control = _ref.read(trainerControlProvider);
    return RideSession(
      id: _rideId ?? const Uuid().v4(),
      startTime: state.startTime ?? _clock(),
      endTime: _clock(),
      mode: control.mode == ControlMode.power ? RideMode.erg : RideMode.sim,
      samples: List.of(_samples),
      workout: _programUsed,
      state: RideState.completed,
      targetGrade: control.mode == ControlMode.grade ? control.grade : null,
      resistanceLevel:
          control.mode == ControlMode.resistance ? control.resistance : null,
    );
  }

  /// Saves the ride and returns to idle.
  Future<RideSession> save(String name) async {
    final session = buildSession();
    await _ref.read(rideRepositoryProvider).saveRide(session, name: name);
    _ref.invalidate(rideHistoryProvider);
    _ref.invalidate(rideStatsProvider);
    await _end();
    return session;
  }

  /// Drops the ride without saving it.
  Future<void> discard() => _end();

  Future<void> _end() async {
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    _samples.clear();
    _rideId = null;
    state = const RideSessionState();
    await _ref.read(trainerControlProvider.notifier).onRideEnded();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// One second of recording (public for tests).
  void tick() {
    if (!state.isRecording) return;
    final elapsed = _stopwatch.elapsed;
    _recordSample();
    state = state.copyWith(
      elapsed: elapsed,
      distance: _distance.value,
      sampleCount: _samples.length,
    );
    final control = _ref.read(trainerControlProvider.notifier);
    _programUsed =
        _ref.read(trainerControlProvider).program?.plan ?? _programUsed;
    control.onRideTick(elapsed);
  }

  void _recordSample() {
    final telemetry = _ref.read(currentTelemetryProvider);
    final hrMonitor = _ref.read(hrConnectionProvider);
    final heartRate = hrMonitor.isConnected
        ? hrMonitor.currentHeartRate
        : telemetry.heartRate;

    // currentTelemetryProvider only holds values received in the last seconds:
    // no trainer data means no trainer fields (never the last known values).
    final trainer = telemetry.hasData;
    if (!trainer && heartRate == null) return;

    if (trainer) {
      _distance.update(telemetry.totalDistance);
      _energy.update(telemetry.totalEnergy);
    }
    _samples.add(TelemetrySample(
      timestamp: _clock(),
      power: trainer ? telemetry.instantPower : null,
      cadence: trainer ? telemetry.instantCadence?.round() : null,
      speed: trainer ? telemetry.instantSpeed : null,
      heartRate: heartRate,
      distance: trainer && _distance.seen ? _distance.value : null,
      calories: trainer && _energy.seen ? _energy.value : null,
    ));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Turns a cumulative trainer counter into a value relative to the ride start,
/// surviving counter resets (trainer restarted, reconnection).
class _CounterBaseline {
  int? _baseline;
  int? _lastRaw;
  int value = 0;

  bool get seen => _baseline != null;

  void reset() {
    _baseline = null;
    _lastRaw = null;
    value = 0;
  }

  void update(int? raw) {
    if (raw == null) return;
    final last = _lastRaw;
    if (_baseline == null) {
      _baseline = raw;
    } else if (last != null && raw < last) {
      // Counter restarted: continue from the value already ridden.
      _baseline = raw - value;
    }
    _lastRaw = raw;
    value = math.max(0, raw - _baseline!);
  }
}
