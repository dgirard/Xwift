import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/features/ride/ride_checkpoint.dart';
import 'package:ridecontroller/models/ride_session.dart';
import 'package:ridecontroller/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpHome(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  MemoryRideCheckpointStore? store,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(ProviderScope(
    overrides: [
      rideCheckpointStoreProvider
          .overrideWithValue(store ?? MemoryRideCheckpointStore()),
    ],
    child: MaterialApp(theme: ThemeData.dark(), home: const WelcomeScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final size in const [Size(800, 600), Size(360, 640), Size(390, 844)]) {
    testWidgets(
        'home screen offers to ride without a trainer '
        '(${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      await pumpHome(tester, size: size);

      expect(find.text('Xwift'), findsOneWidget);
      expect(find.text('Rouler'), findsOneWidget);
      expect(find.text('Connecter un home trainer'), findsOneWidget);
      expect(find.textContaining('Pas de home trainer ?'), findsOneWidget);
    });
  }

  testWidgets('home screen offers to recover a ride cut by the app closing',
      (tester) async {
    final start = DateTime(2026, 1, 10, 18);
    final store = MemoryRideCheckpointStore()
      ..data = RideCheckpoint(
        session: RideSession(
          id: 'r1',
          startTime: start,
          endTime: start.add(const Duration(minutes: 40)),
          mode: RideMode.sim,
          samples: const [],
        ),
        elapsed: const Duration(minutes: 35, seconds: 12),
        distance: 14200,
      ).encode();

    await pumpHome(tester, store: store);

    expect(find.text('Sortie interrompue retrouvée'), findsOneWidget);
    expect(find.text('35:12 · 14,2 km'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });
}
