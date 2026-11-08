import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ridecontroller/features/bluetooth/ble_provider.dart';
import 'package:ridecontroller/features/ftms/ftms_provider.dart';
import 'package:ridecontroller/features/ride/ride_checkpoint.dart';
import 'package:ridecontroller/models/ftms_device.dart';
import 'package:ridecontroller/screens/ride_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_ftms.dart';

List<int> u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> u24(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF];

class _ConnectedBle extends BleConnectionNotifier {
  _ConnectedBle() {
    state = const BleConnectionState(
      status: ConnectionStatus.ready,
      connectedDevice: FtmsDevice(id: 'AA:BB', name: 'Zwift Hub', rssi: -50),
    );
  }

  @override
  Future<void> autoConnect() async {}
}

class _OfflineBle extends BleConnectionNotifier {
  @override
  Future<void> autoConnect() async {}
}

void main() {
  late DateTime now;
  late FakeFtms ftms;

  Future<void> pumpRideScreen(
    WidgetTester tester, {
    bool connected = true,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'ftp': 250});

    final router = GoRouter(initialLocation: '/ride', routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/ride', builder: (_, __) => const RideScreen()),
      GoRoute(path: '/connect', builder: (_, __) => const SizedBox()),
      GoRoute(
        path: '/hr-monitor',
        builder: (_, __) => const Scaffold(body: Text('Écran cardio')),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bleConnectionProvider
            .overrideWith((ref) => connected ? _ConnectedBle() : _OfflineBle()),
        ftmsControlProvider.overrideWith(
          (ref) => ftms = FakeFtms(ref, ready: connected, clock: () => now),
        ),
        rideCheckpointStoreProvider
            .overrideWithValue(MemoryRideCheckpointStore()),
      ],
      child: MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
  }

  setUp(() => now = DateTime(2026, 1, 10, 18));

  testWidgets('shows what the trainer sends, never stale values',
      (tester) async {
    await pumpRideScreen(tester);
    expect(find.textContaining('En attente des données'), findsOneWidget);

    // Real Indoor Bike Data frame: 31.40 km/h, 88 rpm, 212 W, heart rate 0.
    ftms.handleIndoorBikeData(
        [...u16(0x0244), ...u16(3140), ...u16(176), ...u16(212), 0]);
    await tester.pump();
    expect(find.text('212'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('31,4'), findsOneWidget);
    expect(find.text('Z3 · Tempo · 85 % FTP'), findsOneWidget,
        reason: 'zone computed with the FTP of the profile (250 W)');
    expect(find.textContaining('En attente des données'), findsNothing);

    // Second frame of a split record ("More Data"): distance only.
    now = now.add(const Duration(milliseconds: 250));
    ftms.handleIndoorBikeData([...u16(0x0011), ...u24(1200)]);
    await tester.pump();
    expect(find.text('212'), findsOneWidget, reason: 'no flicker to "--"');

    // The trainer goes silent: values go away instead of freezing.
    now = now.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('212'), findsNothing);
    expect(find.textContaining('En attente des données'), findsOneWidget);
  });

  testWidgets('setting the power is applied and confirmed', (tester) async {
    await pumpRideScreen(tester);
    ftms.handleIndoorBikeData([...u16(0x0040), ...u16(3000), ...u16(212)]);
    await tester.pump();

    await tester.tap(find.text('Puissance'));
    await tester.pump();
    expect(find.text('Cible 150 W'), findsOneWidget);
    expect(find.text('+62 W'), findsOneWidget, reason: 'actual vs target');

    await tester.tap(find.text('+10 W'));
    await tester.pump();
    await tester.pump();
    expect(ftms.commands.last, 'power 160');
    expect(find.text('Cible 160 W'), findsOneWidget);
    expect(find.text('Appliqué par le home trainer'), findsOneWidget);

    await tester.tap(find.text('250 W')); // "Seuil" preset = 100 % FTP
    await tester.pump();
    await tester.pump();
    expect(ftms.commands.last, 'power 250');
  });

  testWidgets('works without a trainer and says how to connect',
      (tester) async {
    await pumpRideScreen(tester, connected: false);
    expect(find.text('Aucun home trainer'), findsOneWidget);
    expect(find.textContaining('Home trainer non connecté'), findsOneWidget);

    await tester.tap(find.text('+0,5 %'));
    await tester.pump();
    expect(find.text('+0,5'), findsOneWidget);
    expect(
        find.textContaining('il sera envoyé à la connexion'), findsOneWidget);
    expect(ftms.commands, isEmpty);

    await tester.tap(find.text('Démarrer la sortie'));
    await tester.pump();
    expect(find.text('ENREGISTREMENT'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Terminer'), findsNothing, reason: 'pause first');

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Terminer'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
  });

  testWidgets('the heart rate tile leads to pairing a monitor', (tester) async {
    await pumpRideScreen(tester);
    expect(find.text('Connecter'), findsOneWidget);
    await tester.tap(find.text('Connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Écran cardio'), findsOneWidget);
  });

  testWidgets('each mode explains itself, even on a small screen',
      (tester) async {
    await pumpRideScreen(tester, size: const Size(360, 640));
    expect(find.text('Simule une route : plus ça monte, plus c\'est dur.'),
        findsOneWidget);
    await tester.tap(find.text('Puissance'));
    await tester.pump();
    expect(
        find.text('Le home trainer impose cette puissance.'), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    testWidgets('fits a ${size.width.toInt()}×${size.height.toInt()} screen',
        (tester) async {
      await pumpRideScreen(tester, size: size);
      ftms.handleIndoorBikeData(
          [...u16(0x0244), ...u16(3140), ...u16(176), ...u16(1212), 0]);
      for (final mode in ['Puissance', 'Résistance', 'Pente']) {
        await tester.tap(find.text(mode));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
