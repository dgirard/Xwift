import 'package:equatable/equatable.dart';

/// A structured workout plan for ERG mode
class WorkoutPlan extends Equatable {
  const WorkoutPlan({
    this.id,
    required this.name,
    required this.intervals,
    this.description,
    this.author,
    this.ftp,
  });

  final String? id;
  final String name;
  final List<WorkoutInterval> intervals;
  final String? description;
  final String? author;
  final int? ftp; // FTP used to create this workout (for % based workouts)

  /// Total duration of the workout
  Duration get totalDuration {
    return intervals.fold(
      Duration.zero,
      (total, interval) => total + interval.duration,
    );
  }

  /// Total work in kilojoules (estimated)
  int get estimatedKJ {
    int totalSeconds = 0;
    int totalWattSeconds = 0;

    for (final interval in intervals) {
      final seconds = interval.duration.inSeconds;
      totalSeconds += seconds;
      totalWattSeconds += seconds * interval.targetPower;
    }

    return totalWattSeconds ~/ 1000; // kJ
  }

  /// Get the interval at a given elapsed time
  WorkoutInterval? getIntervalAt(Duration elapsed) {
    Duration cumulative = Duration.zero;
    for (final interval in intervals) {
      cumulative += interval.duration;
      if (elapsed < cumulative) {
        return interval;
      }
    }
    return null;
  }

  /// Get interval index at a given elapsed time
  int getIntervalIndexAt(Duration elapsed) {
    Duration cumulative = Duration.zero;
    for (int i = 0; i < intervals.length; i++) {
      cumulative += intervals[i].duration;
      if (elapsed < cumulative) {
        return i;
      }
    }
    return intervals.length - 1;
  }

  /// Get elapsed time within the current interval
  Duration getElapsedInInterval(Duration totalElapsed) {
    Duration cumulative = Duration.zero;
    for (final interval in intervals) {
      if (totalElapsed < cumulative + interval.duration) {
        return totalElapsed - cumulative;
      }
      cumulative += interval.duration;
    }
    return Duration.zero;
  }

  /// Get remaining time in current interval
  Duration getRemainingInInterval(Duration totalElapsed) {
    Duration cumulative = Duration.zero;
    for (final interval in intervals) {
      final intervalEnd = cumulative + interval.duration;
      if (totalElapsed < intervalEnd) {
        return intervalEnd - totalElapsed;
      }
      cumulative = intervalEnd;
    }
    return Duration.zero;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'intervals': intervals.map((i) => i.toJson()).toList(),
      'description': description,
      'author': author,
      'ftp': ftp,
    };
  }

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] as String?,
      name: json['name'] as String,
      intervals: (json['intervals'] as List)
          .map((i) => WorkoutInterval.fromJson(i as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
      author: json['author'] as String?,
      ftp: json['ftp'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, name, intervals, description, author, ftp];
}

/// A single interval within a workout
class WorkoutInterval extends Equatable {
  const WorkoutInterval({
    required this.duration,
    required this.targetPower,
    this.name,
    this.cadenceTarget,
  });

  final Duration duration;
  final int targetPower; // Absolute watts
  final String? name; // e.g., "Warmup", "Interval 1", "Recovery"
  final int? cadenceTarget; // Optional target cadence

  /// Create from FTP percentage
  factory WorkoutInterval.fromFtpPercent({
    required Duration duration,
    required double ftpPercent,
    required int ftp,
    String? name,
    int? cadenceTarget,
  }) {
    return WorkoutInterval(
      duration: duration,
      targetPower: (ftp * ftpPercent).round(),
      name: name,
      cadenceTarget: cadenceTarget,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'durationSeconds': duration.inSeconds,
      'targetPower': targetPower,
      'name': name,
      'cadenceTarget': cadenceTarget,
    };
  }

  factory WorkoutInterval.fromJson(Map<String, dynamic> json) {
    return WorkoutInterval(
      duration: Duration(seconds: json['durationSeconds'] as int),
      targetPower: json['targetPower'] as int,
      name: json['name'] as String?,
      cadenceTarget: json['cadenceTarget'] as int?,
    );
  }

  @override
  List<Object?> get props => [duration, targetPower, name, cadenceTarget];
}

/// Current state of workout execution
class WorkoutState extends Equatable {
  const WorkoutState({
    required this.plan,
    required this.currentIntervalIndex,
    required this.elapsed,
    required this.isRunning,
    this.biasPercent = 100,
  });

  final WorkoutPlan plan;
  final int currentIntervalIndex;
  final Duration elapsed;
  final bool isRunning;
  final int biasPercent; // Power adjustment (80-120%)

  WorkoutInterval get currentInterval => plan.intervals[currentIntervalIndex];

  int get adjustedTargetPower =>
      (currentInterval.targetPower * biasPercent / 100).round();

  Duration get elapsedInInterval => plan.getElapsedInInterval(elapsed);

  Duration get remainingInInterval => plan.getRemainingInInterval(elapsed);

  Duration get remainingTotal => plan.totalDuration - elapsed;

  double get intervalProgress {
    final interval = currentInterval;
    final elapsedInInt = elapsedInInterval;
    return elapsedInInt.inMilliseconds / interval.duration.inMilliseconds;
  }

  double get totalProgress {
    return elapsed.inMilliseconds / plan.totalDuration.inMilliseconds;
  }

  bool get isComplete => elapsed >= plan.totalDuration;

  WorkoutState copyWith({
    WorkoutPlan? plan,
    int? currentIntervalIndex,
    Duration? elapsed,
    bool? isRunning,
    int? biasPercent,
  }) {
    return WorkoutState(
      plan: plan ?? this.plan,
      currentIntervalIndex: currentIntervalIndex ?? this.currentIntervalIndex,
      elapsed: elapsed ?? this.elapsed,
      isRunning: isRunning ?? this.isRunning,
      biasPercent: biasPercent ?? this.biasPercent,
    );
  }

  @override
  List<Object?> get props =>
      [plan, currentIntervalIndex, elapsed, isRunning, biasPercent];
}
