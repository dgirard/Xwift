import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'bike_telemetry.dart';
import 'workout_plan.dart';

/// Ride mode - SIM (simulation) or ERG (ergometer/target power)
enum RideMode {
  sim('SIM Mode'),
  erg('ERG Mode');

  const RideMode(this.label);
  final String label;
}

/// Current ride session state
enum RideState {
  idle,
  starting,
  active,
  paused,
  stopping,
  completed,
}

/// Represents an active or completed ride session
class RideSession extends Equatable {
  const RideSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.mode,
    required this.samples,
    this.workout,
    this.state = RideState.idle,
    this.currentGear = 11,
    this.targetPower,
    this.targetGrade,
    this.resistanceLevel,
  });

  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final RideMode mode;
  final List<TelemetrySample> samples;
  final WorkoutPlan? workout;
  final RideState state;
  final int currentGear;
  final int? targetPower; // For ERG mode
  final double? targetGrade; // For SIM mode
  final double? resistanceLevel;

  /// Duration of the ride
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Total distance in meters
  int get totalDistance {
    if (samples.isEmpty) return 0;
    return samples.last.distance ?? 0;
  }

  /// Total calories
  int get totalCalories {
    if (samples.isEmpty) return 0;
    return samples.last.calories ?? 0;
  }

  /// Average power
  int? get averagePower {
    final powerSamples = samples.where((s) => s.power != null).toList();
    if (powerSamples.isEmpty) return null;
    final sum = powerSamples.fold<int>(0, (sum, s) => sum + s.power!);
    return sum ~/ powerSamples.length;
  }

  /// Max power
  int? get maxPower {
    final powerSamples = samples.where((s) => s.power != null).toList();
    if (powerSamples.isEmpty) return null;
    return powerSamples.map((s) => s.power!).reduce((a, b) => a > b ? a : b);
  }

  /// Average cadence
  int? get averageCadence {
    final cadenceSamples = samples.where((s) => s.cadence != null).toList();
    if (cadenceSamples.isEmpty) return null;
    final sum = cadenceSamples.fold<int>(0, (sum, s) => sum + s.cadence!);
    return sum ~/ cadenceSamples.length;
  }

  /// Average heart rate
  int? get averageHeartRate {
    final hrSamples = samples.where((s) => s.heartRate != null).toList();
    if (hrSamples.isEmpty) return null;
    final sum = hrSamples.fold<int>(0, (sum, s) => sum + s.heartRate!);
    return sum ~/ hrSamples.length;
  }

  /// Average speed in km/h
  double? get averageSpeed {
    final speedSamples = samples.where((s) => s.speed != null).toList();
    if (speedSamples.isEmpty) return null;
    final sum = speedSamples.fold<double>(0, (sum, s) => sum + s.speed!);
    return sum / speedSamples.length;
  }

  RideSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    RideMode? mode,
    List<TelemetrySample>? samples,
    WorkoutPlan? workout,
    RideState? state,
    int? currentGear,
    int? targetPower,
    double? targetGrade,
    double? resistanceLevel,
  }) {
    return RideSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      mode: mode ?? this.mode,
      samples: samples ?? this.samples,
      workout: workout ?? this.workout,
      state: state ?? this.state,
      currentGear: currentGear ?? this.currentGear,
      targetPower: targetPower ?? this.targetPower,
      targetGrade: targetGrade ?? this.targetGrade,
      resistanceLevel: resistanceLevel ?? this.resistanceLevel,
    );
  }

  /// Serialize for checkpoint recovery
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'mode': mode.name,
      'samples': samples.map((s) => s.toJson()).toList(),
      'workout': workout?.toJson(),
      'state': state.name,
      'currentGear': currentGear,
      'targetPower': targetPower,
      'targetGrade': targetGrade,
      'resistanceLevel': resistanceLevel,
    };
  }

  factory RideSession.fromJson(Map<String, dynamic> json) {
    return RideSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      mode: RideMode.values.byName(json['mode'] as String),
      samples: (json['samples'] as List)
          .map((s) => TelemetrySample.fromJson(s as Map<String, dynamic>))
          .toList(),
      workout: json['workout'] != null
          ? WorkoutPlan.fromJson(json['workout'] as Map<String, dynamic>)
          : null,
      state: RideState.values.byName(json['state'] as String),
      currentGear: json['currentGear'] as int? ?? 11,
      targetPower: json['targetPower'] as int?,
      targetGrade: (json['targetGrade'] as num?)?.toDouble(),
      resistanceLevel: (json['resistanceLevel'] as num?)?.toDouble(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RideSession.fromJsonString(String jsonString) {
    return RideSession.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  List<Object?> get props => [
        id,
        startTime,
        endTime,
        mode,
        samples,
        workout,
        state,
        currentGear,
        targetPower,
        targetGrade,
        resistanceLevel,
      ];
}
