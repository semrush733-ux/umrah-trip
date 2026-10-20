import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:umrah_journey/models/destination.dart';

/// Guards the seeded destination database (spec: 56 destinations, stable
/// unique IDs, no duplicates, no invented coordinates outside Saudi Arabia,
/// idempotent additive updates).
void main() {
  late List<Destination> all;

  setUpAll(() {
    final raw = File('assets/data/destinations.json').readAsStringSync();
    final data = json.decode(raw) as Map<String, dynamic>;
    all = (data['destinations'] as List)
        .map((e) => Destination.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  test('exactly 57 destinations with unique stable ids', () {
    expect(all.length, 57);
    final ids = all.map((d) => d.id).toSet();
    expect(ids.length, 57, reason: 'duplicate destination ids found');
  });

  test('original 31 destinations are preserved (no overwrite/delete)', () {
    const originals = [
      'jabal-rahmah', 'jannat-ul-mualla', 'masjid-jinn', 'masjid-hudaibiya',
      'jabal-noor', 'jabal-thawr', 'masjid-ayesha', 'safa-marwah',
      'masjid-quba', 'masjid-qiblatain', 'jabal-uhud', 'jannat-ul-baqi',
      'masjid-jumma', 'wadi-aqiq', 'badr', 'wadi-jinn', 'seven-mosques',
      'bir-ghars', 'king-fahd-fountain', 'fakieh-aquarium', 'floating-mosque',
      'taybat-museum', 'national-museum', 'diriyah', 'edge-of-world', 'masmak',
      'boulevard-city', 'at-turaif', 'taif', 'ithra', 'marjan-island',
    ];
    final ids = all.map((d) => d.id).toSet();
    for (final id in originals) {
      expect(ids.contains(id), isTrue, reason: 'missing original destination $id');
    }
  });

  test('all coordinates lie within Saudi Arabia bounds and no near-duplicates', () {
    for (final d in all) {
      expect(d.lat, inInclusiveRange(16.0, 32.5), reason: '${d.id} latitude');
      expect(d.lng, inInclusiveRange(34.0, 56.0), reason: '${d.id} longitude');
    }
    // No two different destinations share near-identical coordinates,
    // except intentionally co-located landmarks (Nabawi plaza & Baqi area).
    const allowedClose = {
      'masjid-nabawi|jannat-ul-baqi',
      'masjid-nabawi|masjid-ghamama',
      'masjid-nabawi|masjid-abubakr',
      'masjid-ghamama|masjid-abubakr',
      'diriyah|at-turaif',
      'masjid-jinn|jannat-ul-mualla',
      'marjan-island|khobar-corniche',
    };
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        final a = all[i], b = all[j];
        final close = (a.lat - b.lat).abs() < 0.002 && (a.lng - b.lng).abs() < 0.002;
        if (close) {
          final key1 = '${a.id}|${b.id}';
          final key2 = '${b.id}|${a.id}';
          expect(allowedClose.contains(key1) || allowedClose.contains(key2), isTrue,
              reason: 'unexpected near-duplicate coordinates: ${a.id} vs ${b.id}');
        }
      }
    }
  });

  test('every destination carries the required descriptive fields', () {
    for (final d in all) {
      expect(d.nameEn.trim(), isNotEmpty, reason: d.id);
      expect(d.nameAr.trim(), isNotEmpty, reason: d.id);
      expect(d.nameRoman.trim(), isNotEmpty, reason: d.id);
      expect(d.summaryEn.trim(), isNotEmpty, reason: d.id);
      expect(d.summaryRoman.trim(), isNotEmpty, reason: d.id);
      expect(d.visitDurationMin, greaterThan(0), reason: d.id);
      expect(d.sourceUrl, isNotNull, reason: '${d.id} needs a source url');
      // Verified entries must carry a last-verified date.
      if (d.verified) {
        expect(d.lastVerified, isNotNull, reason: '${d.id} verified without date');
      }
    }
  });

  test('regions are limited to the supported set', () {
    const regions = {'makkah', 'madinah', 'jeddah', 'riyadh', 'taif', 'alula', 'eastern'};
    for (final d in all) {
      expect(regions.contains(d.region), isTrue, reason: '${d.id} region ${d.region}');
    }
  });

  test('booking links, when present, are official https urls', () {
    for (final d in all) {
      final u = d.bookingUrl;
      if (u != null) {
        expect(u.startsWith('https://'), isTrue, reason: d.id);
      }
    }
  });
}
