import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:umrah_journey/screens/splash_screen.dart';
import 'package:umrah_journey/services/app_state.dart';

void main() {
  testWidgets('animated splash shows branding then hands off to the app',
      (tester) async {
    // Skip plugin-backed init (SharedPreferences/SQLite) in the test env.
    final app = AppState()..ready = true;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(
          home: SplashScreen(next: Scaffold(body: Text('HOME'))),
        ),
      ),
    );

    // Branding is visible during the coded animation.
    expect(find.text('UMRAH TRIP'), findsOneWidget);
    expect(find.text('Your Smart Umrah & Ziyarat Companion'), findsOneWidget);
    expect(find.text('by BWP Experts'), findsOneWidget);

    // Let the 2.5s intro elapse, the ready-check run, and the 600ms
    // fade/slide route transition complete.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('HOME'), findsOneWidget);
  });
}
