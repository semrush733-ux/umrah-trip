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
    ('masjid-nabawi', 'Nabi ﷺ ki masjid — 1 namaz = 1000; Rawdah (Nusuk permit)'),
    ('masjid-quba', 'Har hafte (khas kar Saturday) 2 rakat = Umrah ka sawab — Tirmidhi 324'),
    ('jannat-ul-baqi', 'Nabi ﷺ khud ziyarat farmate aur ahl-e-Baqi ke liye dua karte — Muslim 974'),
    ('jabal-uhud', '"Uhud hum se muhabbat karta hai…" — Bukhari 4084; Shuhada ko salam'),
    ('masjid-ayesha', 'Makkah walon ka Umrah miqat — Hazrat Aisha (RA) ki sunnat'),
    ('abyar-ali', 'Nabi ﷺ ne yahin se ihram bandha — Bukhari 1533'),
    ('safa-marwah', 'Sa\'i ka maqam — Qur\'an 2:158'),
    ('masjid-khayf', 'Nabi ﷺ aur (riwayatan) 70 anbiya ki namaz ki jagah'),
  ];

  static const _tier2 = <(String, String)>[
    ('jabal-noor', 'Ghar-e-Hira — pehli wahi ka maqam (charhai ikhtiyari)'),
    ('jabal-thawr', 'Hijrat ka ghaar — Qur\'an 9:40'),
    ('jabal-rahmah', 'Maidan-e-Arafat — Khutbah Hajjat-ul-Wida'),
    ('masjid-nimrah', 'Arafah ke din ki masjid'),
    ('mina', 'Khaimon ka shehar; Masjid-e-Khayf yahin'),
    ('muzdalifah', 'Al-Mash\'ar al-Haram — Qur\'an 2:198'),
    ('masjid-qiblatain', 'Qibla ki tabdeeli ka maqam — 2:144'),
    ('seven-mosques', 'Ghazwa-e-Khandaq ka mahaz'),
    ('masjid-jumma', 'Tareekh ka pehla Jumu\'ah'),
    ('jannat-ul-mualla', 'Hazrat Khadijah (RA) ka qabristan'),
    ('badr', 'Yawm-al-Furqan ka maidan (poray din ka safar)'),
    ('bir-ghars', 'Nabi ﷺ ka pasandeeda kunwan'),
    ('bir-uthman', 'Hazrat Usman (RA) ka sadqa-e-jariya'),
    ('masjid-ghamama', 'Eid ki namazon ka maqam'),
    ('quran-printing-complex', 'Mushaf-e-Madinah ka markaz'),
  ];

  static const _tier3 = <(String, String)>[
    ('al-balad', 'UNESCO purana Jeddah — hujjaj ka tareekhi darwaza'),
    ('floating-mosque', 'Samandar par khubsurat masjid'),
    ('king-fahd-fountain', 'Dunya ka sab se buland fountain'),
    ('taif', 'Thanda pahari shehar — seerat ka Safar-e-Taif bhi'),
    ('al-hada', 'Cable car aur pahari nazare'),
    ('clock-tower', 'Haram ka panorama + museum'),
    ('hira-district', 'Wahi ki kahani ka jadeed museum'),
    ('hegra', 'UNESCO Mada\'in Salih — qaum-e-Thamud (ibrat ke sath)'),
    ('alula-oldtown', 'Purana shehar + Elephant Rock'),
    ('edge-of-world', 'Riyadh ka mashhoor qudrati ajooba'),
    ('boulevard-city', 'Riyadh entertainment'),
    ('ithra', 'Dhahran ka cultural landmark'),
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
          tier('Zaroor jayen — Sunnat se sabit',
              'In maqamat ki ziyarat Nabi ﷺ ke amal se sabit hai',
              Colors.green, Icons.verified_rounded, _tier1),
          tier('Behtar hai — Seerat o tareekh',
              'Azeem waqiat ke maqamat — ibrat aur mohabbat ke sath',
              AppColors.gold, Icons.auto_stories_rounded, _tier2),
          tier('Sair o tafreeh',
              'Khubsurat jagahein — deeni fazilat nahi, family time ke liye',
              Colors.blueGrey, Icons.photo_camera_rounded, _tier3),
        ],
      ),
    );
  }
}
