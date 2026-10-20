import 'package:flutter_test/flutter_test.dart';
import 'package:umrah_journey/services/prayer_times.dart';

void main() {
  group('PrayerCalculator (Umm al-Qura, Makkah)', () {
    // Reference: Makkah 21.4225N 39.8262E, UTC+3. Times vary by convention by
    // a few minutes; we assert sane windows rather than exact minutes.
    test('mid-June day produces ordered, plausible times', () {
      final t = PrayerCalculator.forDate(
          date: DateTime(2026, 6, 15), lat: 21.4225, lng: 39.8262);
      expect(t.fajr.isBefore(t.sunrise), isTrue);
      expect(t.sunrise.isBefore(t.dhuhr), isTrue);
      expect(t.dhuhr.isBefore(t.asr), isTrue);
      expect(t.asr.isBefore(t.maghrib), isTrue);
      expect(t.maghrib.isBefore(t.isha), isTrue);
      // Plausible local windows for Makkah in June:
      expect(t.fajr.hour, inInclusiveRange(4, 5));
      expect(t.dhuhr.hour, inInclusiveRange(12, 12));
      expect(t.maghrib.hour, inInclusiveRange(18, 19));
      // Umm al-Qura: Isha exactly 90 min after Maghrib.
      expect(t.isha.difference(t.maghrib).inMinutes, 90);
    });

    test('mid-December day stays plausible', () {
      final t = PrayerCalculator.forDate(
          date: DateTime(2026, 12, 15), lat: 21.4225, lng: 39.8262);
      expect(t.fajr.hour, inInclusiveRange(5, 6));
      expect(t.maghrib.hour, inInclusiveRange(17, 18));
      expect(t.isha.difference(t.maghrib).inMinutes, 90);
    });

    test('next() returns the first upcoming prayer and skips sunrise', () {
      final t = PrayerCalculator.forDate(
          date: DateTime(2026, 6, 15), lat: 21.4225, lng: 39.8262);
      final beforeFajr = t.fajr.subtract(const Duration(minutes: 10));
      expect(t.next(beforeFajr)?.$1, 'Fajr');
      final betweenSunriseAndDhuhr = t.sunrise.add(const Duration(minutes: 10));
      expect(t.next(betweenSunriseAndDhuhr)?.$1, 'Dhuhr');
      final afterIsha = t.isha.add(const Duration(minutes: 10));
      expect(t.next(afterIsha), isNull);
    });
  });

  group('Qibla bearing', () {
    test('from Madinah the qibla is roughly south (≈176-180°)', () {
      final b = qiblaBearing(24.4672, 39.6111);
      expect(b, inInclusiveRange(170, 185));
    });
    test('from Karachi the qibla is roughly west (≈265-272°)', () {
      final b = qiblaBearing(24.8607, 67.0011);
      expect(b, inInclusiveRange(260, 275));
    });
    test('from Jeddah qibla points east-ish toward Makkah', () {
      final b = qiblaBearing(21.5433, 39.1728);
      expect(b, inInclusiveRange(85, 115));
    });
  });
}
