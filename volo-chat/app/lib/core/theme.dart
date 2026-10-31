import 'package:flutter/material.dart';

/// Volo Chat brand: deep night violet with a fresh mint accent.
class VoloColors {
  static const violet = Color(0xFF6C4CF1);
  static const violetDeep = Color(0xFF4B2FD1);
  static const mint = Color(0xFF2EE59D); // seen ticks, online dot, accents
  static const mintDark = Color(0xFF12B981);
  static const night = Color(0xFF0D0B1E);
  static const nightSurface = Color(0xFF17142E);
  static const nightCard = Color(0xFF1F1B3D);
  static const cloud = Color(0xFFF5F4FB);
  static const ink = Color(0xFF16132B);
  static const muted = Color(0xFF8E8AA8);
  static const bubbleMine = Color(0xFF6C4CF1);
  static const bubbleMineLight = Color(0xFFE6E0FF);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF7B5CFF), Color(0xFF4B2FD1), Color(0xFF1B8F7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Back-compat names used by the shared chat/call widgets.
class AppColors {
  static const emerald = VoloColors.violet;
  static const gold = VoloColors.mint;
  static const goldLight = Color(0xFFB8F5DC);
  static const slate = VoloColors.ink;
}

ThemeData buildLightTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: VoloColors.violet,
    primary: VoloColors.violet,
    secondary: VoloColors.mint,
    surface: Colors.white,
    brightness: Brightness.light,
  );
  return _decorate(ThemeData(useMaterial3: true, colorScheme: cs, scaffoldBackgroundColor: VoloColors.cloud),
      onSurface: VoloColors.ink);
}

ThemeData buildDarkTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: VoloColors.violet,
    primary: const Color(0xFF9B85FF),
    secondary: VoloColors.mint,
    surface: VoloColors.nightSurface,
    brightness: Brightness.dark,
  );
  return _decorate(ThemeData(useMaterial3: true, colorScheme: cs, scaffoldBackgroundColor: VoloColors.night),
      onSurface: const Color(0xFFEDEBFA));
}

ThemeData _decorate(ThemeData t, {required Color onSurface}) => t.copyWith(
      textTheme: t.textTheme.apply(bodyColor: onSurface, displayColor: onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
