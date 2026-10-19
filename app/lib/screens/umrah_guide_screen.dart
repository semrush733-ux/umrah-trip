import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Umrah ritual guidance for Masjid al-Haram — Ihram, Tawaf, Sa'i, Halq —
/// with references, plus Rawdah permit information via the official Nusuk
/// platform. Educational summary only; pilgrims should confirm fiqh details
/// with their scholars/group leaders. Works fully offline.
class UmrahGuideScreen extends StatelessWidget {
  const UmrahGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Umrah Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.emerald, AppColors.emeraldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Umrah has four essential acts: Ihram (with intention at the '
                'miqat), Tawaf of the Kaaba, Sa\'i between Safa and Marwah, '
                'and shaving/shortening the hair. This guide is a concise, '
                'referenced summary — confirm details with your group\'s scholar.',
                style: TextStyle(color: Colors.white, height: 1.55),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Step(
            n: 1,
            title: 'Ihram at the Miqat',
            body:
                'Bathe or make wudu, wear the two unstitched white garments (men), '
                'pray if it is a time of prayer, then make the intention: '
                '"Labbayk Allahumma \'Umrah". From Madinah the miqat is '
                'Dhul-Hulayfah (Abyar Ali); people already inside Makkah use '
                'Masjid Aisha (Tan\'im) for a new Umrah. While in ihram avoid '
                'perfume, cutting hair/nails, and the other prohibitions.\n\n'
                'Talbiyah: Labbayk Allahumma labbayk, labbayka la sharika laka '
                'labbayk, innal-hamda wan-ni\'mata laka wal-mulk, la sharika lak.',
            refs: 'Bukhari 1533–1540 (miqats); Muslim 1184 (talbiyah)',
          ),
          const _Step(
            n: 2,
            title: 'Tawaf — seven circuits of the Kaaba',
            body:
                'Enter Masjid al-Haram, approach the Black Stone corner, face it '
                'and raise your hand saying "Bismillahi wallahu akbar" (kiss or '
                'touch it only if easily possible — never push). Keep the Kaaba '
                'on your LEFT and complete seven circuits, ending each at the '
                'Black Stone line. Men uncover the right shoulder (idtiba) and '
                'walk briskly (raml) in the first three circuits of this tawaf. '
                'Between the Yemeni corner and the Black Stone say: "Rabbana '
                'atina fid-dunya hasanah wa fil-akhirati hasanah wa qina '
                '\'adhab an-nar". After tawaf, pray two rak\'ahs behind Maqam '
                'Ibrahim if possible (anywhere in the mosque otherwise) and '
                'drink Zamzam.',
            refs: 'Bukhari 1603–1616; Muslim 1218 (the Prophet\'s ﷺ Umrah/Hajj description)',
          ),
          const _Step(
            n: 3,
            title: 'Sa\'i — Safa to Marwah, seven lengths',
            body:
                'Proceed to as-Safa reciting: "Innas-Safa wal-Marwata min '
                'sha\'a\'irillah" (Qur\'an 2:158). Climb Safa, face the Kaaba, '
                'praise Allah and make du\'a. Walk to Marwah — men jog lightly '
                'between the green lights — that is one length; Marwah back to '
                'Safa is the second. Complete seven, finishing at Marwah. '
                'There is no fixed du\'a during Sa\'i — remember Hajar (AS), '
                'whose search for water these steps commemorate.',
            refs: 'Qur\'an 2:158; Muslim 1218',
          ),
          const _Step(
            n: 4,
            title: 'Halq or Taqsir — exiting Ihram',
            body:
                'Men shave the head (halq — more virtuous) or shorten all the '
                'hair evenly (taqsir); women cut a fingertip\'s length from the '
                'end of their hair. With this your Umrah is complete and the '
                'ihram restrictions end. May Allah accept it!',
            refs: 'Bukhari 1727–1729 (du\'a for those who shave)',
          ),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified_rounded, color: AppColors.emerald),
                      SizedBox(width: 8),
                      Text('Rawdah & permits — official Nusuk',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Visiting the Rawdah ash-Sharifah in Masjid an-Nabawi requires '
                    'a free time-slot permit booked on the official Nusuk '
                    'platform. Book one slot per person, carry ID, and arrive at '
                    'your gate on time. Umrah itself currently needs no separate '
                    'permit for visit-visa travellers, but rules change — always '
                    'check Nusuk. A permit or booking is only confirmed when the '
                    'official platform confirms it; this app never confirms '
                    'bookings on its own.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://www.nusuk.sa'),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open official Nusuk (nusuk.sa)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  final String body;
  final String refs;
  const _Step({required this.n, required this.title, required this.body, required this.refs});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.gold,
                  child: Text('$n',
                      style: const TextStyle(
                          color: AppColors.slate, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style:
                          const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(height: 1.55)),
            const SizedBox(height: 8),
            Text('Refs: $refs',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}
