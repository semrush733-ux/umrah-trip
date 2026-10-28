import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'screens/call_screen.dart';
import 'screens/root.dart';
import 'screens/splash_screen.dart';
import 'services/account_service.dart';
import 'services/app_state.dart';
import 'services/notifications_service.dart';
import 'services/pair_state.dart';
import 'services/site_service.dart';
import 'services/social_service.dart';

/// Lets services open screens (e.g. an incoming call) from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UmrahJourneyApp());
}

class UmrahJourneyApp extends StatefulWidget {
  const UmrahJourneyApp({super.key});
  @override
  State<UmrahJourneyApp> createState() => _UmrahJourneyAppState();
}

class _UmrahJourneyAppState extends State<UmrahJourneyApp> {
  late final AppState state;
  late final PairState pairState;
  late final SiteService siteService;
  late final AccountService accountService;
  late final SocialService socialService;

  @override
  void initState() {
    super.initState();
    state = AppState();
    pairState = PairState(state);
    siteService = SiteService();
    accountService = AccountService(state, pairState);
    socialService = SocialService(accountService, pairState);
    siteService.addListener(_onSiteUpdate);
    socialService.incomingCalls.stream.listen((c) {
      if (socialService.inCall) {
        // Already on a call → tell the caller we're busy.
        socialService.callEnd(c.thread, c.callId, busy: true);
        return;
      }
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;
      socialService.inCall = true; // block duplicates until the screen opens
      nav.push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallScreen.incoming(
              thread: c.thread,
              peerName: c.callerName,
              video: c.video,
              peerAvatar: c.avatar ?? socialService.avatarFor(c.thread),
              callId: c.callId)));
    });
    state.init().catchError((e) {
      // Never let a startup error strand the user on the splash screen.
      debugPrint('AppState.init error: $e');
      state.forceReady();
    }).whenComplete(() {
      try {
        pairState.init();
      } catch (_) {}
      try {
        siteService.init();
      } catch (_) {}
      try {
        // Ask for notification access from inside the app (calls & chats).
        NotificationsService.instance.init().then((_) => Future.delayed(
            const Duration(seconds: 3), NotificationsService.instance.requestPermission));
      } catch (_) {}
      accountService
          .init()
          .then((_) => socialService.init())
          .then((_) => accountService.refreshProfile())
          .catchError((_) {});
    });
  }

  void _onSiteUpdate() {
    // Merge admin-managed destinations and surface fresh announcements.
    state.mergeRemoteDestinations(siteService.remoteDestinations);
    final a = siteService.announcement;
    if (a != null && siteService.announcementIsNew) {
      NotificationsService.instance.showAnnouncement(a.title, a.body);
    }
  }

  @override
  void dispose() {
    siteService.removeListener(_onSiteUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: pairState),
        ChangeNotifierProvider.value(value: siteService),
        ChangeNotifierProvider.value(value: accountService),
        ChangeNotifierProvider.value(value: socialService),
      ],
      child: Consumer<AppState>(
        builder: (context, app, _) {
          return StringsScope(
            lang: app.language,
            child: Directionality(
              textDirection: app.language.direction,
              child: MaterialApp(
                navigatorKey: appNavigatorKey,
                title: 'Umrah Trip',
                debugShowCheckedModeBanner: false,
                theme: buildLightTheme(),
                darkTheme: buildDarkTheme(),
                themeMode: app.themeMode,
                builder: (context, child) => Directionality(
                  textDirection: app.language.direction,
                  child: child ?? const SizedBox.shrink(),
                ),
                home: const SplashScreen(next: RootScreen()),
              ),
            ),
          );
        },
      ),
    );
  }
}
