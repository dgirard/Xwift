import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ridecontroller/app.dart';

void main() {
  testWidgets('App starts and shows welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: XwiftApp(),
      ),
    );

    // Verify that the welcome screen is shown
    expect(find.text('Xwift'), findsOneWidget);
    expect(find.text('Connecter mon Ride'), findsOneWidget);
  });
}
