import 'package:geolocator/geolocator.dart';

/// Thin wrapper over geolocator. Real GPS only — no simulated positions.
/// Permission is requested explicitly from UI actions, never silently.
class LocationService {
  Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  /// Returns null when the user declines or services are off — callers must
  /// fall back to manual city selection (spec requirement).
  Future<Position?> currentPosition({bool request = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && request) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  /// Live updates for the moving blue marker on map/navigation views.
  Stream<Position> positionStream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      );
}
