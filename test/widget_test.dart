import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in const [Size(800, 600), Size(360, 640), Size(390, 844)]) {
    testWidgets(
        'home screen offers to ride without a trainer '
        '(${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(ProviderScope(
        child:
            MaterialApp(theme: ThemeData.dark(), home: const WelcomeScreen()),
      ));
      await tester.pump();

      expect(find.text('Xwift'), findsOneWidget);
      expect(find.text('Rouler'), findsOneWidget);
      expect(find.text('Connecter un home trainer'), findsOneWidget);
      expect(find.textContaining('Pas de home trainer ?'), findsOneWidget);
    });
  }
}
