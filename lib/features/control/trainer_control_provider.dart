import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ftms_constants.dart';
import '../../models/ftms_device.dart';
import '../../models/workout_plan.dart';
import '../ftms/ftms_provider.dart';

/// How the effort is set. The trainer applies only one at a time (FTMS).
enum ControlMode {
  /// Simulated slope (SIM): the effort follows speed and cadence.
  grade,

  /// Target power (ERG): the trainer holds the power whatever the cadence.
  power,

  /// Fixed brake level: the effort grows with cadence.
  resistance,
}

/// What happened to the current setting, as shown to the rider.
enum ApplyStatus {
  /// Nothing sent yet.
  idle,

  /// No trainer ready: the setting will be sent on connection.
  waitingTrainer,
  sending,
  applied,

  /// The trainer refuses control (another app may be controlling it).
  noControl,

  /// The trainer does not support this mode.
  notSupported,

  /// The trainer rejected the value.
  rejected,

  /// The trainer did not answer.
  noResponse,
}

/// Resistance levels offered to the rider, derived from the trainer range.
class ResistanceScale {
  const ResistanceScale(this.min, this.max, this.step);

  /// Default when the trainer does not publish its range.
  static const fallback = ResistanceScale(0, 10, 0.5);

  factory ResistanceScale.from(ResistanceRange? range) {
    if (range == null || range.maximum <= range.minimum) return fallback;
    var step = _niceStep((range.maximum - range.minimum) / 20);
    if (range.increment > 0 && step < range.increment) step = range.increment;
    return ResistanceScale(range.minimum, range.maximum, step);
  }

  final double min;
  final double max;
  final double step;

  /// A comfortable starting level: a quarter of the range.
  double get initial => snap(min + (max - min) * 0.25);

  double snap(double value) {
    final snapped = min + ((value - min) / step).round() * step;
    final clamped = snapped.clamp(min, max).toDouble();
    return double.parse(clamped.toStringAsFixed(2));
  }

  double fraction(double value) =>
      max > min ? ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble() : 0;

  static double _niceStep(double raw) {
    const steps = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    for (final s in steps) {
      if (s >= raw) return s;
    }
    return steps.last;
  }
}

/// A structured workout being followed in ERG mode.
class WorkoutProgram {
  const WorkoutProgram({
    required this.plan,
    this.elapsed = Duration.zero,
    this.intensity = 100,
  });

  final WorkoutPlan plan;
  final Duration elapsed;

  /// Percentage applied to every target of the plan (50–150 %).
  final int intensity;

  int get index => plan.getIntervalIndexAt(elapsed);
  WorkoutInterval get interval => plan.intervals[index];
  WorkoutInterval? get nextInterval =>
      index + 1 < plan.intervals.length ? plan.intervals[index + 1] : null;
  Duration get remainingInInterval => plan.getRemainingInInterval(elapsed);
  Duration get remainingTotal {
    final remaining = plan.totalDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double get intervalProgress {
    final total = interval.duration.inMilliseconds;
    if (total <= 0) return 1;
    final done = plan.getElapsedInInterval(elapsed).inMilliseconds;
    return (done / total).clamp(0.0, 1.0).toDouble();
  }

  bool get isFinished => elapsed >= plan.totalDuration;

  int targetFor(WorkoutInterval interval) =>
      (interval.targetPower * intensity / 100).round();

  /// Current target in watts (0 = free ride interval).
  int get target => targetFor(interval);

  WorkoutProgram copyWith({Duration? elapsed, int? intensity}) {
    return WorkoutProgram(
      plan: plan,
      elapsed: elapsed ?? this.elapsed,
      intensity: intensity ?? this.intensity,
    );
  }
}

class TrainerControlState {
  const TrainerControlState({
    this.mode = ControlMode.grade,
    this.grade = 0,
    this.targetPower = 150,
    this.resistance,
    this.program,
    this.status = ApplyStatus.idle,
    this.programFinished = false,
  });

  final ControlMode mode;

  /// Simulated slope in percent.
  final double grade;

  /// Manual ERG target in watts.
  final int targetPower;

  /// Resistance level (null until chosen: starts at a quarter of the range).
  final double? resistance;
  final WorkoutProgram? program;
  final ApplyStatus status;

  /// The last program ran to its end (cleared when another one starts).
  final bool programFinished;

  /// Power actually requested from the trainer in ERG mode.
  int get effectiveTargetPower => program?.target ?? targetPower;

  TrainerControlState copyWith({
    ControlMode? mode,
    double? grade,
    int? targetPower,
    double? resistance,
    WorkoutProgram? program,
    bool clearProgram = false,
    ApplyStatus? status,
    bool? programFinished,
  }) {
    return TrainerControlState(
      mode: mode ?? this.mode,
      grade: grade ?? this.grade,
      targetPower: targetPower ?? this.targetPower,
      resistance: resistance ?? this.resistance,
      program: clearProgram ? null : program ?? this.program,
      status: status ?? this.status,
      programFinished: programFinished ?? this.programFinished,
    );
  }
}

/// Settings the rider chooses and their delivery to the trainer.
///
/// Lives for the whole app session: settings survive navigation and
/// reconnections, and are (re)sent as soon as a trainer is ready.
final trainerControlProvider =
    StateNotifierProvider<TrainerControlNotifier, TrainerControlState>((ref) {
  final notifier = TrainerControlNotifier(ref);
  ref.listen<bool>(
    ftmsControlProvider.select((s) => s.isReady),
    (previous, ready) {
      if (ready) {
        notifier.onTrainerReady();
      } else if (previous == true) {
        notifier.onTrainerLost();
      }
    },
    fireImmediately: true,
  );
  ref.listen<bool>(
    ftmsControlProvider.select((s) => s.hasControl),
    (previous, hasControl) {
      if (previous == true && !hasControl) notifier.onControlLost();
    },
  );
  return notifier;
});

class TrainerControlNotifier extends StateNotifier<TrainerControlState> {
  TrainerControlNotifier(this._ref) : super(const TrainerControlState());

  static const minGrade = -10.0;
  static const maxGrade = 20.0;
  static const gradeStep = 0.5;
  static const powerStep = 10;
  static const intensityStep = 5;

  final Ref _ref;
  bool _inFlight = false;
  bool _dirty = false;
  Duration? _lastRideElapsed;

  FtmsControlNotifier get _ftms => _ref.read(ftmsControlProvider.notifier);
  FtmsControlState get _ftmsState => _ref.read(ftmsControlProvider);

  ResistanceScale get resistanceScale =>
      ResistanceScale.from(_ftmsState.resistanceRange);

  /// Power limits: the trainer range when known.
  ({int min, int max}) get powerLimits {
    final range = _ftmsState.powerRange;
    if (range != null && range.maximum > range.minimum) {
      return (min: range.minimum < 25 ? 25 : range.minimum, max: range.maximum);
    }
    return (min: 25, max: 1500);
  }

  double get resistanceLevel => state.resistance ?? resistanceScale.initial;

  // --- Mode -------------------------------------------------------------------

  void setMode(ControlMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(
      mode: mode,
      // Leaving ERG ends the program: it only makes sense in ERG.
      clearProgram: mode != ControlMode.power,
      resistance: mode == ControlMode.resistance ? resistanceLevel : null,
    );
    _apply();
  }

  // --- Slope ------------------------------------------------------------------

  void changeGrade(int steps) => setGrade(state.grade + steps * gradeStep);

  void setGrade(double grade) {
    final snapped = (grade / gradeStep).round() * gradeStep;
    state = state.copyWith(
      mode: ControlMode.grade,
      grade: snapped.clamp(minGrade, maxGrade).toDouble(),
      clearProgram: true,
    );
    _apply();
  }

  // --- Power ------------------------------------------------------------------

  /// One tap on −/+ in ERG: changes the target, or the intensity of a program.
  void changePower(int steps) {
    if (state.program != null) {
      changeIntensity(steps);
    } else {
      setPower(state.targetPower + steps * powerStep);
    }
  }

  void setPower(int watts) {
    final limits = powerLimits;
    final rounded = (watts / 5).round() * 5;
    state = state.copyWith(
      mode: ControlMode.power,
      targetPower: rounded.clamp(limits.min, limits.max),
      clearProgram: true,
    );
    _apply();
  }

  void changeIntensity(int steps) {
    final program = state.program;
    if (program == null) return;
    final intensity =
        (program.intensity + steps * intensityStep).clamp(50, 150);
    state = state.copyWith(program: program.copyWith(intensity: intensity));
    _apply();
  }

  void startProgram(WorkoutPlan plan) {
    if (plan.intervals.isEmpty) return;
    state = state.copyWith(
      mode: ControlMode.power,
      program: WorkoutProgram(plan: plan),
      programFinished: false,
    );
    _apply();
  }

  /// Jumps to the start of the next interval (or ends the program).
  void skipInterval() {
    final program = state.program;
    if (program == null) return;
    var nextStart = Duration.zero;
    for (var i = 0; i <= program.index; i++) {
      nextStart += program.plan.intervals[i].duration;
    }
    if (nextStart >= program.plan.totalDuration) {
      stopProgram();
      return;
    }
    state = state.copyWith(program: program.copyWith(elapsed: nextStart));
    _apply();
  }

  /// Stops the program and keeps its current target as the manual target.
  void stopProgram() {
    final program = state.program;
    if (program == null) return;
    final keep = program.target > 0 ? program.target : state.targetPower;
    state = state.copyWith(targetPower: keep, clearProgram: true);
    _apply();
  }

  // --- Resistance -------------------------------------------------------------

  void changeResistance(int steps) =>
      setResistance(resistanceLevel + steps * resistanceScale.step);

  void setResistance(double level) {
    state = state.copyWith(
      mode: ControlMode.resistance,
      resistance: resistanceScale.snap(level),
      clearProgram: true,
    );
    _apply();
  }

  // --- Delivery ---------------------------------------------------------------

  /// Sends the current setting again (after a failure).
  void retry() => _apply();

  void onTrainerReady() => _apply();

  void onTrainerLost() {
    state = state.copyWith(status: ApplyStatus.waitingTrainer);
  }

  void onControlLost() {
    if (_ftmsState.isReady && state.status == ApplyStatus.applied) {
      state = state.copyWith(status: ApplyStatus.noControl);
    }
  }

  // --- Ride lifecycle ---------------------------------------------------------

  Future<void> onRideStarted() async {
    _lastRideElapsed = Duration.zero;
    if (_ftmsState.isReady) await _ftms.start();
    _apply();
  }

  Future<void> onRidePaused() async {
    _lastRideElapsed = null;
    if (_ftmsState.isReady) await _ftms.pause();
  }

  Future<void> onRideResumed(Duration rideElapsed) async {
    _lastRideElapsed = rideElapsed;
    if (_ftmsState.isReady) await _ftms.start();
    _apply();
  }

  Future<void> onRideEnded() async {
    _lastRideElapsed = null;
    if (state.program != null) state = state.copyWith(clearProgram: true);
    if (_ftmsState.isReady) await _ftms.stop();
  }

  /// Called every second while recording: advances the program and sends the
  /// new target when an interval starts.
  void onRideTick(Duration rideElapsed) {
    final last = _lastRideElapsed;
    _lastRideElapsed = rideElapsed;
    final program = state.program;
    if (program == null || last == null) return;
    final delta = rideElapsed - last;
    if (delta <= Duration.zero) return;

    final next = program.copyWith(elapsed: program.elapsed + delta);
    if (next.isFinished) {
      final keep = program.target > 0 ? program.target : state.targetPower;
      state = state.copyWith(
        targetPower: keep,
        clearProgram: true,
        programFinished: true,
      );
      _apply();
      return;
    }
    final intervalChanged = next.index != program.index;
    state = state.copyWith(program: next);
    if (intervalChanged) _apply();
  }

  /// Sends the current setting. Taps during a command are merged: when it
  /// completes, only the latest value is sent.
  void _apply() {
    if (!_ftmsState.isReady) {
      state = state.copyWith(status: ApplyStatus.waitingTrainer);
      return;
    }
    if (_inFlight) {
      _dirty = true;
      return;
    }
    unawaited(_sendLoop());
  }

  Future<void> _sendLoop() async {
    _inFlight = true;
    try {
      do {
        _dirty = false;
        if (!mounted) return;
        state = state.copyWith(status: ApplyStatus.sending);
        final response = await _sendCurrent();
        if (!mounted) return;
        state = state.copyWith(status: statusOf(response));
      } while (_dirty && _ftmsState.isReady);
    } finally {
      _inFlight = false;
    }
  }

  Future<FtmsResponse> _sendCurrent() {
    final current = state;
    switch (current.mode) {
      case ControlMode.grade:
        return _ftms.setGrade(current.grade);
      case ControlMode.power:
        final target = current.effectiveTargetPower;
        // Free ride interval of a program: flat road instead of 0 W in ERG.
        if (target <= 0) return _ftms.setGrade(current.grade);
        return _ftms.setTargetPower(target);
      case ControlMode.resistance:
        return _ftms.setResistance(resistanceLevel);
    }
  }

  static ApplyStatus statusOf(FtmsResponse response) {
    if (response.isSuccess) return ApplyStatus.applied;
    switch (response.failure) {
      case FtmsFailure.notConnected:
        return ApplyStatus.waitingTrainer;
      case FtmsFailure.timeout:
      case FtmsFailure.writeError:
        return ApplyStatus.noResponse;
      case FtmsFailure.none:
        break;
    }
    if (response.requestOpCode == FtmsConstants.opCodeRequestControl ||
        response.resultCode == FtmsConstants.resultControlNotPermitted) {
      return ApplyStatus.noControl;
    }
    if (response.resultCode == FtmsConstants.resultNotSupported) {
      return ApplyStatus.notSupported;
    }
    return ApplyStatus.rejected;
  }
}
