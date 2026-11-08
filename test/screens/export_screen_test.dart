import 'package:app_links/app_links.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ridecontroller/core/database/app_database.dart';
import 'package:ridecontroller/core/database/database_provider.dart';
import 'package:ridecontroller/features/strava/strava_provider.dart';
import 'package:ridecontroller/screens/export_screen.dart';

/// No deep links in tests.
class _NoAppLinks implements AppLinks {
  @override
  Stream<Uri> get uriLinkStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.insertRide(RidesCompanion.insert(
      id: 'r1',
      name: const Value('Sortie du soir'),
      startTime: DateTime(2026, 11, 7, 18),
      endTime: Value(DateTime(2026, 11, 7, 19)),
      mode: 'sim',
      durationSeconds: const Value(3300),
      averagePower: const Value(185),
      averageCadence: const Value(88),
    ));
  });

  tearDown(() => database.close());

  Future<void> pumpExportScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/export',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/export', builder: (_, __) => const ExportScreen()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appLinksProvider.overrideWithValue(_NoAppLinks()),
      ],
      child: MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  testWidgets('lists saved rides with their actions', (tester) async {
    await pumpExportScreen(tester);

    expect(find.text('Sortie du soir'), findsOneWidget);
    expect(find.text('55 min'), findsOneWidget);
    expect(find.text('185W'), findsOneWidget);
    expect(find.text('.FIT'), findsOneWidget);
    expect(find.text('.TCX'), findsOneWidget);
    expect(find.text('Illustrer'), findsOneWidget);
    expect(find.text('Configurer'), findsOneWidget,
        reason: 'Strava not configured yet');
  });

  testWidgets('deleting a ride asks first, then removes it', (tester) async {
    await pumpExportScreen(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer l\'activite ?'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('Sortie du soir'), findsNothing);
    expect(find.text('Aucune activite'), findsOneWidget);
    expect(await database.getAllRides(), isEmpty);
  });
}
