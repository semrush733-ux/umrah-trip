import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small app-wide state: theme and the phone's current position.
class DeviceState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  Position? position;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[(p.getInt('volo_theme') ?? ThemeMode.dark.index).clamp(0, 2)];
    notifyListeners();
    refreshLocation(request: false);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('volo_theme', m.index);
  }

  Future<void> refreshLocation({bool request = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && request) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 12));
      notifyListeners();
    } catch (_) {}
  }
}
