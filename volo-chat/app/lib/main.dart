import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/call_screen.dart';
import 'screens/home_screens.dart';
import 'screens/onboarding_screens.dart';
import 'screens/sos_screen.dart';
import 'services/account_service.dart';
import 'services/background_service.dart';
import 'services/device_state.dart';
import 'services/notifications_service.dart';
import 'services/push_service.dart';
import 'services/social_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (d) => Material(
        color: VoloColors.night,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text('Sorry — this screen hit a problem. Please send a screenshot to support.\n\n${d.exceptionAsString()}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          ),
        ),
      );
  runApp(const VoloApp());
}

class VoloApp extends StatefulWidget {
  const VoloApp({super.key});
  @override
  State<VoloApp> createState() => _VoloAppState();
}

class _VoloAppState extends State<VoloApp> with WidgetsBindingObserver {
  final device = DeviceState();
  final account = AccountService();
  late final SocialService social = SocialService(account, device);
  late final PushService push = PushService(account, social);
  bool _bg = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationsService.instance.init();
    device.init();
    account.addListener(_syncBg);
    account.init().then((_) => social.init()).then((_) => push.init()).then((_) => _syncBg());

    social.incomingCalls.stream.listen((c) {
      if (social.inCall) {
        social.callEnd(c.thread, c.callId, busy: true);
        return;
      }
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;
      social.inCall = true;
      nav.push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallScreen.incoming(
              thread: c.thread,
              peerName: social.contactFor(c.thread)?.user.displayName ?? c.callerName,
              peerAvatar: c.avatar ?? social.avatarFor(c.thread),
              video: c.video,
              callId: c.callId)));
    });
    var sosOpen = false;
    social.sosAlerts.stream.listen((a) async {
      final nav = appNavigatorKey.currentState;
      if (nav == null || sosOpen) return;
      sosOpen = true;
      await nav.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => SosAlertScreen(alert: a)));
      sosOpen = false;
    });
  }

  void _syncBg() {
    final want = account.loggedIn && !account.needsProfile;
    if (want && !_bg) {
      _bg = true;
      BackgroundService.start();
    } else if (!want && _bg) {
      _bg = false;
      BackgroundService.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    social.appInForeground = s == AppLifecycleState.resumed;
    if (s == AppLifecycleState.resumed) {
      social.refreshInbox();
      account.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: device),
        ChangeNotifierProvider.value(value: account),
        ChangeNotifierProvider.value(value: social),
      ],
      child: Consumer<DeviceState>(
        builder: (_, d, __) => MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Volo Chat',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: d.themeMode,
          home: SplashScreen(next: () => const AppGate()),
        ),
      ),
    );
  }
}

/// Decides what to show: welcome/sign-in → profile → email → chats.
class AppGate extends StatelessWidget {
  const AppGate({super.key});
  @override
  Widget build(BuildContext context) {
    final a = context.watch<AccountService>();
    Widget child;
    if (!a.ready) {
      child = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!a.loggedIn) {
      child = const WelcomeScreen();
    } else if (a.needsProfile) {
      child = const ProfileSetupScreen();
    } else if (a.needsEmail) {
      child = const EmailVerifyScreen();
    } else {
      child = const HomeShell();
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: child);
  }
}
