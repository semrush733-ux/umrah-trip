import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../services/app_state.dart';
import '../services/prayer_times.dart';

/// Prayer times (Umm al-Qura convention, offline) + live Qibla compass.
class PrayerQiblaScreen extends StatefulWidget {
  const PrayerQiblaScreen({super.key});
  @override
  State<PrayerQiblaScreen> createState() => _PrayerQiblaScreenState();
}

class _PrayerQiblaScreenState extends State<PrayerQiblaScreen> {
  StreamSubscription? _magSub;
  double _heading = 0; // degrees from north (flat phone)
  bool _hasCompass = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    try {
      _magSub = magnetometerEventStream().listen((e) {
        final h = (math.atan2(e.y, e.x) * 180 / math.pi) - 90;
        if (mounted) {
          setState(() {
            _hasCompass = true;
            _heading = (h + 360) % 360;
          });
        }
      }, onError: (_) {});
    } catch (_) {}
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _magSub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Location: GPS if available, otherwise the active city's centre.
    final pos = app.position;
    final center = cityCenters.firstWhere((c) => c.region == app.activeRegion,
        orElse: () => cityCenters.first);
    final lat = pos?.latitude ?? center.lat;
    final lng = pos?.longitude ?? center.lng;

    final nowKsa = saudiNow();
    final times = PrayerCalculator.forDate(
        date: DateTime(nowKsa.year, nowKsa.month, nowKsa.day), lat: lat, lng: lng);
    final next = times.next(nowKsa);
    final qibla = qiblaBearing(lat, lng);
    final needle = (qibla - _heading + 360) % 360;
    final kaabaDist = haversineKm(lat, lng, 21.4225, 39.8262);

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times & Qibla')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Next prayer hero
          Card(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.emerald, AppColors.emeraldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.mosque_rounded, color: AppColors.goldLight, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next == null
                              ? 'All prayers done for today'
                              : 'Next: ${next.$1} at ${DateFormat('HH:mm').format(next.$2)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Saudi time · ${pos != null ? 'your GPS location' : 'city centre (enable GPS for exact)'}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Times table
          Card(
            child: Column(
              children: times.entries.map((e) {
                final isNext = next != null && e.$1 == next.$1;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    switch (e.$1) {
                      'Fajr' => Icons.dark_mode_rounded,
                      'Sunrise' => Icons.wb_twilight_rounded,
                      'Dhuhr' => Icons.light_mode_rounded,
                      'Asr' => Icons.wb_sunny_rounded,
                      'Maghrib' => Icons.wb_twilight,
                      _ => Icons.nights_stay_rounded,
                    },
                    color: isNext ? AppColors.gold : AppColors.emerald,
                  ),
                  title: Text(e.$1,
                      style: TextStyle(
                          fontWeight: isNext ? FontWeight.w800 : FontWeight.w600)),
                  trailing: Text(DateFormat('HH:mm').format(e.$2),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                          color: isNext ? AppColors.gold : null)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Umm al-Qura convention (Fajr 18.5°, Isha = Maghrib + 90 min). Approximate — follow the local adhan for congregation.',
            style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 18),

          // Qibla compass
          Text('Qibla Compass',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dial
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [AppColors.emerald, AppColors.emeraldDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 30),
                            ],
                          ),
                        ),
                        Transform.rotate(
                          angle: -_heading * math.pi / 180,
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text('N',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                    )),
                                Transform.rotate(
                                  angle: qibla * math.pi / 180,
                                  child: const Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 30),
                                      child: Text('🕋', style: TextStyle(fontSize: 34)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Fixed needle
                        const Icon(Icons.navigation_rounded,
                            size: 54, color: AppColors.goldLight),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _hasCompass
                        ? 'Qibla: ${qibla.toStringAsFixed(1)}° · Turn phone until 🕋 is at the top (${needle.toStringAsFixed(0)}° to go)'
                        : 'Qibla direction: ${qibla.toStringAsFixed(1)}° from North · ${formatKm(kaabaDist)} to the Kaaba\n(Compass sensor not available — use any compass and face ${qibla.toStringAsFixed(0)}°)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text('Hold the phone flat, away from magnets/metal.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
