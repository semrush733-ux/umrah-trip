import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'screens/root.dart';
import 'screens/splash_screen.dart';
import 'services/app_state.dart';

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

  @override
  void initState() {
    super.initState();
    state = AppState();
    state.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
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
