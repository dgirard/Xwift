import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/features/ftms/ftms_provider.dart';
import 'package:ridecontroller/features/ride/ride_session_provider.dart';
import 'package:ridecontroller/models/bike_telemetry.dart';

import '../../helpers/fake_ftms.dart';

final _telemetry = StateProvider<BikeTelemetry>((ref) => BikeTelemetry.empty());

void main() {
  late ProviderContainer container;
  late RideSessionNotifier ride;

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
    container = ProviderContainer(overrides: [
      ftmsControlProvider.overrideWith((ref) => FakeFtms(ref)),
      currentTelemetryProvider.overrideWith((ref) => ref.watch(_telemetry)),
    ]);
    ride = container.read(rideSessionProvider.notifier);
    await ride.start();
  });

  tearDown(() => container.dispose());

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

  test('discarding returns to idle', () async {
    trainerSends(power: 200);
    ride.tick();
    await ride.discard();
    expect(container.read(rideSessionProvider).status, RideStatus.idle);
    expect(ride.samples, isEmpty);
  });
}
