import 'package:flutter/material.dart';

/// Umrah Journey brand palette — Saudi-inspired premium look.
class AppColors {
  static const emerald = Color(0xFF086B58);
  static const emeraldDark = Color(0xFF054D40);
  static const ivory = Color(0xFFF8F7F2);
  static const gold = Color(0xFFC8A96B);
  static const goldLight = Color(0xFFE2CFA3);
  static const slate = Color(0xFF18242B);
  static const slateSoft = Color(0xFF4A5A64);

  // Dark mode surfaces
  static const darkBg = Color(0xFF0E1A18);
  static const darkSurface = Color(0xFF14211F);
}

ThemeData buildLightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.emerald,
    primary: AppColors.emerald,
    secondary: AppColors.gold,
    surface: Colors.white,
    brightness: Brightness.light,
  );
  return _decorate(
    ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.ivory,
    ),
    onSurface: AppColors.slate,
  );
}

ThemeData buildDarkTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.emerald,
    primary: const Color(0xFF2FA78F),
    secondary: AppColors.gold,
    surface: AppColors.darkSurface,
    brightness: Brightness.dark,
  );
  return _decorate(
    ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.darkBg,
    ),
    onSurface: const Color(0xFFE8EBE9),
  );
}

ThemeData _decorate(ThemeData t, {required Color onSurface}) {
  return t.copyWith(
    textTheme: t.textTheme.apply(bodyColor: onSurface, displayColor: onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: onSurface,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: t.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      indicatorColor: AppColors.gold.withValues(alpha: 0.25),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onSurface),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
