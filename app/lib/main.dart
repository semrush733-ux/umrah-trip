import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'screens/root.dart';
import 'screens/splash_screen.dart';
import 'services/app_state.dart';
import 'services/notifications_service.dart';
import 'services/pair_state.dart';
import 'services/site_service.dart';

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

  @override
  void initState() {
    super.initState();
    state = AppState();
    pairState = PairState(state);
    siteService = SiteService();
    siteService.addListener(_onSiteUpdate);
    state.init().then((_) {
      pairState.init();
      siteService.init();
      NotificationsService.instance.init();
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
      ],
      child: Consumer<AppState>(
        builder: (context, app, _) {
          return StringsScope(
            lang: app.language,
            child: Directionality(
              textDirection: app.language.direction,
              child: MaterialApp(
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
