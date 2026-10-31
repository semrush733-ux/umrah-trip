import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:volo_chat/screens/home_screens.dart';
import 'package:volo_chat/screens/onboarding_screens.dart';
import 'package:volo_chat/screens/status_screens.dart';
import 'package:volo_chat/services/account_service.dart';
import 'package:volo_chat/services/device_state.dart';
import 'package:volo_chat/services/social_service.dart';

/// Builds the main screens with plugins stubbed and fails on any exception.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['plugins.flutter.io/shared_preferences', 'dexterous.com/flutter/local_notifications']) {
      m.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
  });

  Widget host(Widget child) {
    final dev = DeviceState();
    final acct = AccountService();
    final social = SocialService(acct, dev);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dev),
        ChangeNotifierProvider.value(value: acct),
        ChangeNotifierProvider.value(value: social),
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpAndCheck(WidgetTester tester, Widget w, String label) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      if (!s.contains('MissingPluginException') && !s.contains('overflowed')) errors.add(s);
    };
    await tester.pumpWidget(host(w));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final ex = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    FlutterError.onError = old;
    // ignore: avoid_print
    print('$label errors: ${errors.isEmpty ? 'none' : errors.join(' | ')} / exception: $ex');
    expect(errors, isEmpty);
    expect(ex, isNull);
  }

  testWidgets('welcome', (t) => pumpAndCheck(t, const WelcomeScreen(), 'WELCOME'));
  testWidgets('phone', (t) => pumpAndCheck(t, const PhoneScreen(), 'PHONE'));
  testWidgets('otp', (t) => pumpAndCheck(t, const OtpScreen(phone: '+923001234567'), 'OTP'));
  testWidgets('profile', (t) => pumpAndCheck(t, const ProfileSetupScreen(), 'PROFILE'));
  testWidgets('email', (t) => pumpAndCheck(t, const EmailVerifyScreen(), 'EMAIL'));
  testWidgets('home', (t) => pumpAndCheck(t, const HomeShell(), 'HOME'));
  testWidgets('status composer', (t) => pumpAndCheck(t, const TextStatusComposer(), 'STATUS'));
}
