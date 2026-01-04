import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/bike_telemetry.dart';
import '../../models/ride_session.dart';
import '../../models/workout_plan.dart';
import 'app_database.dart';

/// Provider for the app database
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

/// Repository for ride history operations
class RideRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  RideRepository(this._db);

  /// Save a completed ride session to the database
  Future<void> saveRide(RideSession session) async {
    // Insert ride record
    await _db.insertRide(RidesCompanion.insert(
      id: session.id,
      startTime: session.startTime,
      endTime: Value(session.endTime),
      mode: session.mode.name,
      durationSeconds: Value(session.duration.inSeconds),
      totalDistance: Value(session.totalDistance),
      totalCalories: Value(session.totalCalories),
      averagePower: Value(session.averagePower),
      maxPower: Value(session.maxPower),
      averageCadence: Value(session.averageCadence),
      averageHeartRate: Value(session.averageHeartRate),
      averageSpeed: Value(session.averageSpeed),
      workoutName: Value(session.workout?.name),
      workoutId: Value(session.workout?.id),
    ));

    // Insert samples
    if (session.samples.isNotEmpty) {
      final sampleCompanions = session.samples.map((s) => RideSamplesCompanion.insert(
        rideId: session.id,
        timestamp: s.timestamp,
        power: Value(s.power),
        cadence: Value(s.cadence),
        speed: Value(s.speed),
        heartRate: Value(s.heartRate),
        distance: Value(s.distance),
        calories: Value(s.calories),
      )).toList();

      await _db.insertSamples(sampleCompanions);
    }
  }

  /// Get all saved rides (summary only, without samples)
  Future<List<RideSummary>> getAllRides() async {
    final rides = await _db.getAllRides();
    return rides.map((r) => RideSummary(
      id: r.id,
      startTime: r.startTime,
      endTime: r.endTime,
      mode: RideMode.values.byName(r.mode),
      duration: Duration(seconds: r.durationSeconds),
      totalDistance: r.totalDistance,
      totalCalories: r.totalCalories,
      averagePower: r.averagePower,
      maxPower: r.maxPower,
      averageCadence: r.averageCadence,
      averageHeartRate: r.averageHeartRate,
      averageSpeed: r.averageSpeed,
      workoutName: r.workoutName,
    )).toList();
  }

  /// Load a complete ride session with all samples
  Future<RideSession?> loadRideWithSamples(String rideId) async {
    final ride = await _db.getRideById(rideId);
    if (ride == null) return null;

    final samples = await _db.getSamplesForRide(rideId);

    return RideSession(
      id: ride.id,
      startTime: ride.startTime,
      endTime: ride.endTime,
      mode: RideMode.values.byName(ride.mode),
      samples: samples.map((s) => TelemetrySample(
        timestamp: s.timestamp,
        power: s.power,
        cadence: s.cadence,
        speed: s.speed,
        heartRate: s.heartRate,
        distance: s.distance,
        calories: s.calories,
      )).toList(),
      state: RideState.completed,
    );
  }

  /// Delete a ride and all its samples
  Future<void> deleteRide(String rideId) async {
    await _db.deleteSamplesForRide(rideId);
    await _db.deleteRide(rideId);
  }

  /// Get ride statistics
  Future<RideStats> getStats() async {
    final totalRides = await _db.getTotalRides();
    final totalDuration = await _db.getTotalDuration();
    final totalDistance = await _db.getTotalDistance();

    return RideStats(
      totalRides: totalRides,
      totalDuration: Duration(seconds: totalDuration),
      totalDistance: totalDistance,
    );
  }
}

/// Repository for workout operations
class WorkoutRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  WorkoutRepository(this._db);

  /// Save a workout plan
  Future<void> saveWorkout(WorkoutPlan workout) async {
    final id = workout.id ?? _uuid.v4();
    final intervalsJson = jsonEncode(workout.intervals.map((i) => i.toJson()).toList());

    await _db.insertWorkout(WorkoutsCompanion.insert(
      id: id,
      name: workout.name,
      description: Value(workout.description),
      author: Value(workout.author),
      ftp: Value(workout.ftp),
      intervalsJson: intervalsJson,
      createdAt: DateTime.now(),
    ));
  }

  /// Get all saved workouts
  Future<List<WorkoutPlan>> getAllWorkouts() async {
    final workouts = await _db.getAllWorkouts();
    return workouts.map((w) {
      final intervals = (jsonDecode(w.intervalsJson) as List)
          .map((i) => WorkoutInterval.fromJson(i as Map<String, dynamic>))
          .toList();

      return WorkoutPlan(
        id: w.id,
        name: w.name,
        description: w.description,
        author: w.author,
        ftp: w.ftp,
        intervals: intervals,
      );
    }).toList();
  }

  /// Load a workout by ID
  Future<WorkoutPlan?> getWorkoutById(String id) async {
    final workout = await _db.getWorkoutById(id);
    if (workout == null) return null;

    final intervals = (jsonDecode(workout.intervalsJson) as List)
        .map((i) => WorkoutInterval.fromJson(i as Map<String, dynamic>))
        .toList();

    return WorkoutPlan(
      id: workout.id,
      name: workout.name,
      description: workout.description,
      author: workout.author,
      ftp: workout.ftp,
      intervals: intervals,
    );
  }

  /// Delete a workout
  Future<void> deleteWorkout(String id) => _db.deleteWorkout(id);

  /// Mark a workout as used
  Future<void> markWorkoutUsed(String id) => _db.markWorkoutUsed(id);
}

/// Summary of a ride (without samples)
class RideSummary {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final RideMode mode;
  final Duration duration;
  final int totalDistance;
  final int totalCalories;
  final int? averagePower;
  final int? maxPower;
  final int? averageCadence;
  final int? averageHeartRate;
  final double? averageSpeed;
  final String? workoutName;

  RideSummary({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.mode,
    required this.duration,
    required this.totalDistance,
    required this.totalCalories,
    this.averagePower,
    this.maxPower,
    this.averageCadence,
    this.averageHeartRate,
    this.averageSpeed,
    this.workoutName,
  });
}

/// Overall ride statistics
class RideStats {
  final int totalRides;
  final Duration totalDuration;
  final int totalDistance;

  RideStats({
    required this.totalRides,
    required this.totalDuration,
    required this.totalDistance,
  });

  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String get formattedDistance {
    if (totalDistance < 1000) {
      return '$totalDistance m';
    }
    return '${(totalDistance / 1000).toStringAsFixed(1)} km';
  }
}

/// Provider for ride repository
final rideRepositoryProvider = Provider<RideRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RideRepository(db);
});

/// Provider for workout repository
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WorkoutRepository(db);
});

/// Provider for ride history (async)
final rideHistoryProvider = FutureProvider<List<RideSummary>>((ref) async {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getAllRides();
});

/// Provider for saved workouts (async)
final savedWorkoutsProvider = FutureProvider<List<WorkoutPlan>>((ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getAllWorkouts();
});

/// Provider for ride statistics
final rideStatsProvider = FutureProvider<RideStats>((ref) async {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getStats();
});
