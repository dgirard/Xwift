import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_provider.dart';
import '../../models/bike_telemetry.dart';
import '../../models/ride_session.dart';
import '../../models/workout_plan.dart';
import '../control/trainer_control_provider.dart';
import '../ftms/ftms_provider.dart';
import '../heart_rate/hr_monitor_provider.dart';
import 'ride_checkpoint.dart';

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
  return RideSessionNotifier(ref, store: ref.read(rideCheckpointStoreProvider));
});

/// Bumped when the stored checkpoint is saved as a ride or deleted.
final _checkpointVersionProvider = StateProvider<int>((ref) => 0);

/// A ride interrupted by the app being killed, found at startup.
final interruptedRideProvider = FutureProvider<RideCheckpoint?>((ref) async {
  ref.watch(_checkpointVersionProvider);
  if (ref.watch(rideSessionProvider.select((s) => s.isActive))) return null;
  final data = await ref.read(rideCheckpointStoreProvider).read();
  return data == null ? null : RideCheckpoint.decode(data);
});

class RideSessionNotifier extends StateNotifier<RideSessionState> {
  RideSessionNotifier(
    this._ref, {
    required RideCheckpointStore store,
    DateTime Function()? clock,
  })  : _store = store,
        _clock = clock ?? DateTime.now,
        super(const RideSessionState());

  /// A checkpoint every 30 s of riding (and at each pause).
  static const checkpointEvery = 30;

  final Ref _ref;
  final RideCheckpointStore _store;
  final DateTime Function() _clock;

  // Riding time = time restored from a checkpoint + time since (re)start.
  final Stopwatch _stopwatch = Stopwatch();
  Duration _elapsedOffset = Duration.zero;
  int _ticksSinceCheckpoint = 0;

  // Checkpoint writes and deletes run one after the other, so that a write
  // still in progress can never bring back a checkpoint deleted after it.
  Future<void> _storeQueue = Future.value();
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
    _elapsedOffset = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    state = RideSessionState(status: RideStatus.recording, startTime: _clock());
    _startTicker();
    unawaited(checkpointNow());
    await _ref.read(trainerControlProvider.notifier).onRideStarted();
  }

  Future<void> pause() async {
    if (!state.isRecording) return;
    _stopwatch.stop();
    _ticker?.cancel();
    state = state.copyWith(status: RideStatus.paused, elapsed: _elapsed);
    unawaited(checkpointNow());
    await _ref.read(trainerControlProvider.notifier).onRidePaused();
  }

  Future<void> resume() async {
    if (!state.isPaused) return;
    _stopwatch.start();
    _startTicker();
    state = state.copyWith(status: RideStatus.recording);
    await _ref.read(trainerControlProvider.notifier).onRideResumed(_elapsed);
  }

  Duration get _elapsed => _elapsedOffset + _stopwatch.elapsed;

  /// Saves the ride in progress now (also called when the app goes to the
  /// background). Never fails the ride: errors are only logged.
  Future<void> checkpointNow() {
    if (!state.isActive) return Future.value();
    _ticksSinceCheckpoint = 0;
    final rideId = _rideId;
    final data = RideCheckpoint(
      session: buildSession(),
      elapsed: _elapsed,
      distance: _distance.value,
    ).encode();
    return _enqueueStore(() async {
      // The ride may have been saved or dropped while waiting.
      if (!state.isActive || _rideId != rideId) return;
      await _store.write(data);
    });
  }

  Future<void> _enqueueStore(Future<void> Function() operation) {
    return _storeQueue = _storeQueue.then((_) => operation()).catchError(
      (Object e) {
        if (kDebugMode) debugPrint('[Ride] checkpoint storage failed: $e');
      },
    );
  }

  /// Continues an interrupted ride, paused: the rider resumes when ready.
  void restore(RideCheckpoint checkpoint) {
    if (state.isActive) return;
    final session = checkpoint.session;
    _rideId = session.id;
    _samples
      ..clear()
      ..addAll(session.samples);
    _programUsed = session.workout;
    _elapsedOffset = checkpoint.elapsed;
    _stopwatch.reset();
    _distance.resumeFrom(checkpoint.distance);
    _energy.resumeFrom(
      session.samples
              .lastWhere((s) => s.calories != null,
                  orElse: () => TelemetrySample(timestamp: session.startTime))
              .calories ??
          0,
    );
    state = RideSessionState(
      status: RideStatus.paused,
      startTime: session.startTime,
      elapsed: checkpoint.elapsed,
      distance: checkpoint.distance,
      sampleCount: _samples.length,
    );
  }

  /// Saves an interrupted ride as it was at its last checkpoint.
  Future<void> saveInterrupted(RideCheckpoint checkpoint, String name) async {
    final session =
        checkpoint.session.copyWith(activeDuration: checkpoint.elapsed);
    await _ref.read(rideRepositoryProvider).saveRide(session, name: name);
    _ref.invalidate(rideHistoryProvider);
    _ref.invalidate(rideStatsProvider);
    await discardInterrupted();
  }

  Future<void> discardInterrupted() async {
    await _deleteCheckpoint();
    _ref.read(_checkpointVersionProvider.notifier).state++;
  }

  Future<void> _deleteCheckpoint() => _enqueueStore(_store.delete);

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
      activeDuration: _elapsed,
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
    _elapsedOffset = Duration.zero;
    _samples.clear();
    _rideId = null;
    state = const RideSessionState();
    await _deleteCheckpoint();
    await _ref.read(trainerControlProvider.notifier).onRideEnded();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// One second of recording (public for tests).
  void tick() {
    if (!state.isRecording) return;
    final elapsed = _elapsed;
    _recordSample();
    if (++_ticksSinceCheckpoint >= checkpointEvery) unawaited(checkpointNow());
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
  int _resumeOffset = 0;
  int value = 0;

  bool get seen => _baseline != null;

  void reset() => resumeFrom(0);

  /// Continues counting from [ridden] (ride restored from a checkpoint).
  void resumeFrom(int ridden) {
    _baseline = null;
    _lastRaw = null;
    _resumeOffset = ridden;
    value = ridden;
  }

  void update(int? raw) {
    if (raw == null) return;
    final last = _lastRaw;
    if (_baseline == null) {
      _baseline = raw - _resumeOffset;
    } else if (last != null && raw < last) {
      // Counter restarted: continue from the value already ridden.
      _baseline = raw - value;
    }
    _lastRaw = raw;
    value = math.max(0, raw - _baseline!);
  }
}
