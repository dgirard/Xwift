import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridecontroller/core/theme/app_theme.dart';

void main() {
  testWidgets('the theme loads Inter from the app, never from the network',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(body: Text('Xwift')),
    ));
    // Fails if a weight used by the theme is not bundled in assets.
    await tester.runAsync(GoogleFonts.pendingFonts);
    expect(find.text('Xwift'), findsOneWidget);
  });
}
