import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/core/database/app_database.dart';
import 'package:ridecontroller/core/database/database_provider.dart';
import 'package:ridecontroller/features/ftms/ftms_provider.dart';
import 'package:ridecontroller/features/ride/ride_checkpoint.dart';
import 'package:ridecontroller/features/ride/ride_session_provider.dart';
import 'package:ridecontroller/models/bike_telemetry.dart';

import '../../helpers/fake_ftms.dart';

final _telemetry = StateProvider<BikeTelemetry>((ref) => BikeTelemetry.empty());

void main() {
  late MemoryRideCheckpointStore store;
  late AppDatabase database;
  late ProviderContainer container;
  late RideSessionNotifier ride;

  /// A fresh app process sharing the same storage (checkpoint, database).
  ProviderContainer newApp() {
    final app = ProviderContainer(overrides: [
      ftmsControlProvider.overrideWith((ref) => FakeFtms(ref)),
      currentTelemetryProvider.overrideWith((ref) => ref.watch(_telemetry)),
      rideCheckpointStoreProvider.overrideWithValue(store),
      appDatabaseProvider.overrideWithValue(database),
    ]);
    addTearDown(app.dispose);
    return app;
  }

  void trainerSends({int? power, double? cadence, int? distance}) {
    container.read(_telemetry.notifier).state = BikeTelemetry(
      instantPower: power,
      instantCadence: cadence,
      instantSpeed: power == null ? null : 30,
      totalDistance: distance,
      timestamp: DateTime.now(),
    );
  }

  setUp(() async {
    store = MemoryRideCheckpointStore();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    container = newApp();
    ride = container.read(rideSessionProvider.notifier);
    await ride.start();
  });

  test('records what the trainer sends', () {
    trainerSends(power: 210, cadence: 88, distance: 10000);
    ride.tick();
    final sample = ride.samples.single;
    expect(sample.power, 210);
    expect(sample.cadence, 88);
    expect(sample.speed, 30);
    expect(sample.distance, 0, reason: 'distance counts from the ride start');
  });

  test('records nothing from the trainer when no data arrives', () {
    trainerSends(power: 210, cadence: 88);
    ride.tick();
    // Trainer silent or disconnected: the telemetry view is empty.
    container.read(_telemetry.notifier).state = BikeTelemetry.empty();
    ride.tick();
    ride.tick();
    expect(ride.samples, hasLength(1), reason: 'no phantom samples');
  });

  test('distance is relative to the start and survives a counter reset', () {
    trainerSends(power: 200, distance: 10000);
    ride.tick();
    trainerSends(power: 200, distance: 10050);
    ride.tick();
    // Trainer restarted: its counter starts again from 0.
    trainerSends(power: 200, distance: 20);
    ride.tick();
    trainerSends(power: 200, distance: 40);
    ride.tick();
    expect(ride.samples.map((s) => s.distance), [0, 50, 50, 70]);
    expect(container.read(rideSessionProvider).distance, 70);
  });

  test('pause stops recording and resume continues', () async {
    trainerSends(power: 200);
    ride.tick();
    await ride.pause();
    ride.tick(); // ignored while paused
    expect(ride.samples, hasLength(1));
    expect(container.read(rideSessionProvider).isPaused, isTrue);

    await ride.resume();
    ride.tick();
    expect(ride.samples, hasLength(2));
  });

  test('discarding returns to idle and removes the checkpoint', () async {
    trainerSends(power: 200);
    ride.tick();
    expect(store.data, isNotNull, reason: 'checkpoint written at start');
    await ride.discard();
    expect(container.read(rideSessionProvider).status, RideStatus.idle);
    expect(ride.samples, isEmpty);
    expect(store.data, isNull);
  });

  test('a checkpoint still being written cannot outlive the saved ride',
      () async {
    trainerSends(power: 200);
    ride.tick();
    // A checkpoint is requested, then the ride is saved right away.
    final pendingWrite = ride.checkpointNow();
    await ride.save('Sortie');
    await pendingWrite;
    expect(store.data, isNull);
  });

  test('a ride killed with the app is found and continued', () async {
    trainerSends(power: 200, distance: 10000);
    ride.tick();
    trainerSends(power: 210, distance: 10050);
    ride.tick();
    await ride.pause(); // checkpoint

    // The app is killed and restarted.
    container.dispose();
    container = newApp();
    final checkpoint = await container.read(interruptedRideProvider.future);
    expect(checkpoint, isNotNull);
    expect(checkpoint!.session.samples, hasLength(2));
    expect(checkpoint.distance, 50);

    ride = container.read(rideSessionProvider.notifier);
    ride.restore(checkpoint);
    final state = container.read(rideSessionProvider);
    expect(state.isPaused, isTrue, reason: 'the rider resumes when ready');
    expect(state.distance, 50);

    await ride.resume();
    // The trainer was restarted too: its counter is back near 0.
    trainerSends(power: 220, distance: 30);
    ride.tick();
    trainerSends(power: 220, distance: 60);
    ride.tick();
    expect(ride.samples.map((s) => s.distance), [0, 50, 50, 80]);
  });

  test('an interrupted ride can be saved as it was', () async {
    trainerSends(power: 200, distance: 1000);
    ride.tick();
    await ride.pause();
    container.dispose();
    container = newApp();
    final checkpoint = (await container.read(interruptedRideProvider.future))!;

    await container
        .read(rideSessionProvider.notifier)
        .saveInterrupted(checkpoint, 'Sortie interrompue');

    final rides = await container.read(rideHistoryProvider.future);
    expect(rides.single.name, 'Sortie interrompue');
    expect(rides.single.averagePower, 200);
    expect(store.data, isNull);
    expect(await container.read(interruptedRideProvider.future), isNull);
  });

  test('the saved duration is the riding time, pauses excluded', () async {
    final checkpoint = RideCheckpoint(
      session: ride.buildSession(),
      elapsed: const Duration(minutes: 30),
      distance: 0,
    );
    await ride.discard();
    // Restored at 30 min of riding, then saved: no pause time is added.
    ride.restore(checkpoint);
    await ride.save('Test');
    final saved = (await container.read(rideHistoryProvider.future)).single;
    expect(saved.duration.inMinutes, 30);
  });
}
