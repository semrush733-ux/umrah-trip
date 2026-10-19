import 'dart:math' as math;

/// Saudi Arabia runs on Arabia Standard Time, UTC+03:00, with no DST.
DateTime saudiNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

/// Great-circle (haversine) distance in kilometres.
/// This is a *straight-line* distance — the UI must label it as such and never
/// present it as a driving distance or ETA.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180.0;

String formatKm(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

/// Rough walking time at 4.5 km/h for short distances only (<= 3 km),
/// clearly an estimate, not a routed time.
String? walkingEstimate(double km) {
  if (km > 3) return null;
  final mins = (km / 4.5 * 60).round().clamp(1, 999);
  return '~$mins min walk';
}

/// City centres used for "which city am I in / near" decisions.
class CityCenter {
  final String region;
  final double lat;
  final double lng;
  const CityCenter(this.region, this.lat, this.lng);
}

const cityCenters = <CityCenter>[
  CityCenter('makkah', 21.4225, 39.8262),
  CityCenter('madinah', 24.4672, 39.6111),
  CityCenter('jeddah', 21.5433, 39.1728),
  CityCenter('riyadh', 24.7136, 46.6753),
  CityCenter('taif', 21.2854, 40.4248),
  CityCenter('alula', 26.6086, 37.9230),
  CityCenter('eastern', 26.4207, 50.0888),
];

/// Returns the region whose centre is nearest, or null if the user is far
/// (>120 km) from every supported city.
String? nearestRegion(double lat, double lng) {
  String? best;
  double bestD = double.infinity;
  for (final c in cityCenters) {
    final d = haversineKm(lat, lng, c.lat, c.lng);
    if (d < bestD) {
      bestD = d;
      best = c.region;
    }
  }
  return bestD <= 120 ? best : null;
}
