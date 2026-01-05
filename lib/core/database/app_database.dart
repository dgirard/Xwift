import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Ride history table
class Rides extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get mode => text()(); // 'sim' or 'erg'
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  IntColumn get totalDistance => integer().withDefault(const Constant(0))();
  IntColumn get totalCalories => integer().withDefault(const Constant(0))();
  IntColumn get averagePower => integer().nullable()();
  IntColumn get maxPower => integer().nullable()();
  IntColumn get averageCadence => integer().nullable()();
  IntColumn get averageHeartRate => integer().nullable()();
  RealColumn get averageSpeed => real().nullable()();
  TextColumn get workoutName => text().nullable()();
  TextColumn get workoutId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ride telemetry samples table
class RideSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get rideId => text().references(Rides, #id)();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get power => integer().nullable()();
  IntColumn get cadence => integer().nullable()();
  RealColumn get speed => real().nullable()();
  IntColumn get heartRate => integer().nullable()();
  IntColumn get distance => integer().nullable()();
  IntColumn get calories => integer().nullable()();
}

/// Saved workouts table
class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get author => text().nullable()();
  IntColumn get ftp => integer().nullable()();
  TextColumn get intervalsJson => text()(); // JSON-encoded intervals
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  IntColumn get useCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Rides, RideSamples, Workouts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add name column to rides table
          await m.addColumn(rides, rides.name);
        }
      },
    );
  }

  // Ride operations
  Future<List<Ride>> getAllRides() => (select(rides)
    ..orderBy([(t) => OrderingTerm.desc(t.startTime)])).get();

  Future<Ride?> getRideById(String id) =>
      (select(rides)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertRide(RidesCompanion ride) => into(rides).insert(ride);

  Future<void> updateRide(Ride ride) => update(rides).replace(ride);

  Future<void> updateRideName(String id, String name) async {
    await (update(rides)..where((t) => t.id.equals(id)))
        .write(RidesCompanion(name: Value(name)));
  }

  Future<void> deleteRide(String id) =>
      (delete(rides)..where((t) => t.id.equals(id))).go();

  // Ride samples operations
  Future<List<RideSample>> getSamplesForRide(String rideId) =>
      (select(rideSamples)
        ..where((t) => t.rideId.equals(rideId))
        ..orderBy([(t) => OrderingTerm.asc(t.timestamp)])).get();

  Future<void> insertSample(RideSamplesCompanion sample) =>
      into(rideSamples).insert(sample);

  Future<void> insertSamples(List<RideSamplesCompanion> samples) =>
      batch((batch) => batch.insertAll(rideSamples, samples));

  Future<void> deleteSamplesForRide(String rideId) =>
      (delete(rideSamples)..where((t) => t.rideId.equals(rideId))).go();

  // Workout operations
  Future<List<Workout>> getAllWorkouts() => (select(workouts)
    ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])).get();

  Future<Workout?> getWorkoutById(String id) =>
      (select(workouts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertWorkout(WorkoutsCompanion workout) =>
      into(workouts).insert(workout);

  Future<void> updateWorkout(Workout workout) => update(workouts).replace(workout);

  Future<void> deleteWorkout(String id) =>
      (delete(workouts)..where((t) => t.id.equals(id))).go();

  Future<void> markWorkoutUsed(String id) async {
    final workout = await getWorkoutById(id);
    if (workout != null) {
      await updateWorkout(workout.copyWith(
        lastUsedAt: Value(DateTime.now()),
        useCount: workout.useCount + 1,
      ));
    }
  }

  // Statistics
  Future<int> getTotalRides() async {
    final count = countAll();
    final query = selectOnly(rides)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<int> getTotalDuration() async {
    final sum = rideSamples.id.count();
    final query = selectOnly(rides)..addColumns([rides.durationSeconds.sum()]);
    final result = await query.getSingle();
    return result.read(rides.durationSeconds.sum()) ?? 0;
  }

  Future<int> getTotalDistance() async {
    final query = selectOnly(rides)..addColumns([rides.totalDistance.sum()]);
    final result = await query.getSingle();
    return result.read(rides.totalDistance.sum()) ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ridecontroller.db'));
    return NativeDatabase.createInBackground(file);
  });
}
