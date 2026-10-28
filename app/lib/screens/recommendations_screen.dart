import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../widgets/destination_card.dart';

/// "Kahan jana chahiye?" — three honest tiers:
///  1. Sunnah-proven — visits established from the Prophet's ﷺ practice
///  2. Highly recommended — major sites of seerah/history
///  3. Tourism & leisure — beautiful, but no religious significance
class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  static const _tier1 = <(String, String)>[
    ('masjid-nabawi', 'The Prophet\'s ﷺ mosque — one prayer equals a thousand; Rawdah by Nusuk permit'),
    ('masjid-quba', 'Weekly visit (especially on Saturday); two rak\'ahs carry the reward of an Umrah — Tirmidhi 324'),
    ('jannat-ul-baqi', 'The Prophet ﷺ visited and prayed for those buried here — Muslim 974'),
    ('jabal-uhud', '"Uhud is a mountain that loves us…" — Bukhari 4084; send salam to the martyrs'),
    ('masjid-ayesha', 'The Umrah miqat for those in Makkah — following Aisha (RA)'),
    ('abyar-ali', 'The Prophet ﷺ entered ihram here — Bukhari 1533'),
    ('safa-marwah', 'The place of Sa\'i — Qur\'an 2:158'),
    ('masjid-khayf', 'Where the Prophet ﷺ — and, by narration, 70 prophets — prayed'),
  ];

  static const _tier2 = <(String, String)>[
    ('jabal-noor', 'Cave of Hira — site of the first revelation (the climb is optional)'),
    ('jabal-thawr', 'The cave of the Hijrah — Qur\'an 9:40'),
    ('jabal-rahmah', 'The plain of Arafat — the Farewell Sermon'),
    ('masjid-nimrah', 'The mosque of the Day of Arafah'),
    ('mina', 'The city of tents; home to Masjid al-Khayf'),
    ('muzdalifah', 'Al-Mash\'ar al-Haram — Qur\'an 2:198'),
    ('masjid-qiblatain', 'Where the qibla was changed — 2:144'),
    ('seven-mosques', 'The front line of the Battle of the Trench'),
    ('masjid-jumma', 'Site of the first Jumu\'ah in history'),
    ('jannat-ul-mualla', 'Resting place of Khadijah (RA)'),
    ('badr', 'The battlefield of Yawm al-Furqan (a full-day trip)'),
    ('bir-ghars', 'A well beloved by the Prophet ﷺ'),
    ('bir-uthman', 'Uthman\'s (RA) ongoing charity (sadaqah jariyah)'),
    ('masjid-ghamama', 'Where the Eid prayers were held'),
    ('quran-printing-complex', 'Home of the Madinah Mushaf'),
  ];

  static const _tier3 = <(String, String)>[
    ('al-balad', 'UNESCO old Jeddah — the historic gateway for pilgrims'),
    ('floating-mosque', 'A beautiful mosque over the sea'),
    ('king-fahd-fountain', 'The world\'s tallest fountain'),
    ('taif', 'A cool mountain city — and the Prophet\'s ﷺ journey to Taif'),
    ('al-hada', 'Cable car and mountain views'),
    ('clock-tower', 'Panoramic views of the Haram + museum'),
    ('hira-district', 'A modern museum telling the story of revelation'),
    ('hegra', 'UNESCO Mada\'in Salih — land of Thamud (visit with reflection)'),
    ('alula-oldtown', 'Old town + Elephant Rock'),
    ('edge-of-world', 'Riyadh\'s famous natural wonder'),
    ('boulevard-city', 'Riyadh entertainment'),
    ('ithra', 'Dhahran\'s cultural landmark'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    Widget tier(String title, String subtitle, Color color, IconData icon,
        List<(String, String)> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style:
                        const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(subtitle,
                style: TextStyle(
                    fontSize: 12.5,
                    color:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          ...items.map((e) {
            final d = app.repo.byId(e.$1);
            if (d == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DestinationCard(destination: d, compact: true),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: color),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(e.$2,
                              style: const TextStyle(
                                  fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          tier('Must visit — established by the Sunnah',
              'Visiting these places is established by the practice of the Prophet ﷺ',
              Colors.green, Icons.verified_rounded, _tier1),
          tier('Highly recommended — Seerah and history',
              'Sites of great events — visit with reflection and love',
              AppColors.gold, Icons.auto_stories_rounded, _tier2),
          tier('Sightseeing and leisure',
              'Beautiful places — no religious merit, ideal for family time',
              Colors.blueGrey, Icons.photo_camera_rounded, _tier3),
        ],
      ),
    );
  }
}
