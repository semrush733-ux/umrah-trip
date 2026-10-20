import 'dart:math' as math;

/// Offline prayer-time calculator (standard astronomical method).
/// Default convention: Umm al-Qura (used officially in Saudi Arabia):
///   Fajr 18.5° below horizon, Isha = Maghrib + 90 minutes.
/// Asr: Shafi (shadow = 1x). Values are approximations — for congregational
/// prayer always follow the local masjid/adhan.
class PrayerTimesResult {
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;
  const PrayerTimesResult({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  List<(String, DateTime)> get entries => [
        ('Fajr', fajr),
        ('Sunrise', sunrise),
        ('Dhuhr', dhuhr),
        ('Asr', asr),
        ('Maghrib', maghrib),
        ('Isha', isha),
      ];

  /// Next upcoming prayer relative to [now]; null when Isha has passed.
  (String, DateTime)? next(DateTime now) {
    for (final e in entries) {
      if (e.$1 == 'Sunrise') continue;
      if (e.$2.isAfter(now)) return e;
    }
    return null;
  }
}

class PrayerCalculator {
  /// [date] is a date in the target zone; [utcOffsetHours] e.g. 3.0 for KSA.
  static PrayerTimesResult forDate({
    required DateTime date,
    required double lat,
    required double lng,
    double utcOffsetHours = 3.0,
    double fajrAngle = 18.5,
    int ishaMinutesAfterMaghrib = 90,
  }) {
    final jd = _julianDate(date.year, date.month, date.day) -
        lng / (15.0 * 24.0);

    double timeFor(double angle, {bool afterNoon = true, double? asrFactor}) {
      final t = _computeTime(jd, lat, angle, afterNoon: afterNoon, asrFactor: asrFactor);
      return _fixHour(t + utcOffsetHours - lng / 15.0);
    }

    final dhuhrH = _fixHour(_midDay(jd) + utcOffsetHours - lng / 15.0);
    final fajrH = timeFor(fajrAngle, afterNoon: false);
    final sunriseH = timeFor(0.833, afterNoon: false);
    final maghribH = timeFor(0.833, afterNoon: true);
    final asrH = timeFor(0, afterNoon: true, asrFactor: 1.0);

    DateTime at(double h) {
      final totalMin = (h * 60).round();
      return DateTime(date.year, date.month, date.day)
          .add(Duration(minutes: totalMin));
    }

    final maghrib = at(maghribH);
    return PrayerTimesResult(
      fajr: at(fajrH),
      sunrise: at(sunriseH),
      dhuhr: at(dhuhrH).add(const Duration(minutes: 1)),
      asr: at(asrH),
      maghrib: maghrib,
      isha: maghrib.add(Duration(minutes: ishaMinutesAfterMaghrib)),
    );
  }

  // ---- Astronomy (PrayTimes-style equations) ----
  static double _julianDate(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static (double, double) _sunPosition(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(
        q + 1.915 * _dsin(g) + 0.020 * _dsin(2 * g));
    final e = 23.439 - 0.00000036 * d;
    final dec = _darcsin(_dsin(e) * _dsin(l));
    double ra = _darctan2(_dcos(e) * _dsin(l), _dcos(l)) / 15.0;
    ra = _fixHour(ra);
    final eqt = q / 15.0 - ra;
    return (dec, eqt);
  }

  static double _midDay(double jd) {
    final eqt = _sunPosition(jd).$2;
    return _fixHour(12 - eqt);
  }

  static double _computeTime(double jd, double lat, double angle,
      {required bool afterNoon, double? asrFactor}) {
    final dec = _sunPosition(jd).$1;
    double g = angle;
    if (asrFactor != null) {
      g = -_darccot(asrFactor + _dtan((lat - dec).abs()));
    }
    final mid = _midDay(jd);
    final v = (-_dsin(g) - _dsin(dec) * _dsin(lat)) /
        (_dcos(dec) * _dcos(lat));
    final t = _darccos(v.clamp(-1.0, 1.0)) / 15.0;
    return mid + (afterNoon ? t : -t);
  }

  static double _fixAngle(double a) => a - 360.0 * (a / 360.0).floorToDouble();
  static double _fixHour(double a) => a - 24.0 * (a / 24.0).floorToDouble();
  static double _dsin(double d) => math.sin(d * math.pi / 180);
  static double _dcos(double d) => math.cos(d * math.pi / 180);
  static double _dtan(double d) => math.tan(d * math.pi / 180);
  static double _darcsin(double x) => math.asin(x) * 180 / math.pi;
  static double _darccos(double x) => math.acos(x) * 180 / math.pi;
  static double _darctan2(double y, double x) => math.atan2(y, x) * 180 / math.pi;
  static double _darccot(double x) => math.atan2(1, x) * 180 / math.pi;
}

/// Great-circle initial bearing from a point to the Kaaba, degrees from north.
double qiblaBearing(double lat, double lng) {
  const kLat = 21.4225 * math.pi / 180;
  const kLng = 39.8262 * math.pi / 180;
  final p = lat * math.pi / 180;
  final l = lng * math.pi / 180;
  final y = math.sin(kLng - l);
  final x = math.cos(p) * math.tan(kLat) - math.sin(p) * math.cos(kLng - l);
  var b = math.atan2(y, x) * 180 / math.pi;
  return (b + 360) % 360;
}
