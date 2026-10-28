import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Complete journey companion in three tabs:
///  1. Journey — step-by-step from home/Jeddah airport to the flight back
///  2. Umrah Faraiz — the arkan/wajibat of Umrah
///  3. Hajj Faraiz — the fard and wajib acts of Hajj (incl. Rami days)
/// All offline. Fiqh follows the mainstream positions; pilgrims should
/// confirm details with their own scholars/group.
class JourneyGuideScreen extends StatelessWidget {
  final int initialTab;
  const JourneyGuideScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Journey Guide'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Journey'),
            Tab(text: 'Umrah Faraiz'),
            Tab(text: 'Hajj Faraiz'),
          ]),
        ),
        body: const TabBarView(children: [
          _JourneyTab(),
          _UmrahFaraizTab(),
          _HajjFaraizTab(),
        ]),
      ),
    );
  }
}

// ----------------------------- Journey -----------------------------

class _JourneyStep {
  final String emoji;
  final String title;
  final String body;
  final String? tip;
  const _JourneyStep(this.emoji, this.title, this.body, [this.tip]);
}

const _journeySteps = <_JourneyStep>[
  _JourneyStep('🏠', 'Before you leave home',
      'Take a bath (ghusl), pray two rak\'ahs, settle any debts or trusts and say goodbye to your family. Keep the ihram garments (for men), sandals, essential medicines and travel documents in your hand luggage.',
      'Book any Umrah and Rawdah permits in advance on the official Nusuk app.'),
  _JourneyStep('✈️', 'On the flight — enter ihram before the miqat',
      'Flights to Jeddah pass over a miqat (Qarn al-Manazil or Yalamlam). The cabin crew usually make an announcement — before that point, put on your ihram garments and make the intention: "Labbayk Allahumma \'Umrah", then begin the Talbiyah.',
      'For ease, wear the ihram at home or at the airport and make the intention as you approach the miqat.'),
  _JourneyStep('🛬', 'Arriving at Jeddah Airport',
      'After immigration and baggage reclaim, travel to Makkah by bus, taxi or train (about 1–1.5 hours). Keep reciting the Talbiyah on the way.',
      'Use the app\'s Transport section to request a transfer from Bin-Mukhtar Travels on WhatsApp.'),
  _JourneyStep('🏨', 'Makkah — your hotel',
      'Check in and freshen up. Save your hotel under "My Hotel" in the app so the way back is always one tap away.',
      'Leave for the Haram in a state of wudu, and remember the restrictions of ihram (no perfume, no cutting hair or nails).'),
  _JourneyStep('🕋', 'Tawaf — seven circuits',
      'Begin opposite the Black Stone saying "Bismillahi Allahu Akbar", keeping the Kaaba on your LEFT. Men walk briskly (ramal) in the first three circuits and keep the right shoulder uncovered (idtiba). Between the Yemeni Corner and the Black Stone recite: "Rabbana atina fid-dunya hasanah…".',
      'After Tawaf, pray two rak\'ahs behind Maqam Ibrahim (or anywhere in the mosque), then drink Zamzam.'),
  _JourneyStep('🏃', "Sa'i — seven lengths between Safa and Marwah",
      'Climb Safa, face the Kaaba and make du\'a, then walk to Marwah (men jog lightly between the green lights). Safa to Marwah counts as one length; the seventh ends at Marwah.',
      'There is no fixed du\'a for Sa\'i — make plenty of du\'a in your own words.'),
  _JourneyStep('✂️', 'Halq or Taqsir — Umrah complete!',
      'Men shave the head (preferred) or trim the hair evenly all over; women cut a fingertip\'s length from the end of their hair. The restrictions of ihram are now lifted. May Allah accept your Umrah — Ameen!',
      'Licensed barbers are just outside Marwah.'),
  _JourneyStep('🕌', 'Your days in Makkah',
      'Perform voluntary tawaf, pray in the Haram and visit the Makkah sites in the app: Jabal al-Nour, Jabal Thawr, Masjid Aisha (the miqat for a further Umrah), Jannat al-Mu\'alla and a drive through Mina, Arafat and Muzdalifah.',
      'Every site has one-tap "Navigate", and "Check In" saves the memory.'),
  _JourneyStep('🚄', 'Travelling to Madinah',
      'Take the Haramain High-Speed Railway (about 2.5 hours) or travel by road (about 4–5 hours). No ihram is required for Madinah.',
      'Buy train tickets at sar.hhr.sa or at the station; book early in peak seasons.'),
  _JourneyStep('💚', 'Madinah — Al-Masjid an-Nabawi ﷺ',
      'Pray in the Prophet\'s Mosque (one prayer equals a thousand), send salam to the Prophet ﷺ, and book a free Nusuk permit for the RAWDAH. Visit Quba (a Saturday sunnah), Qiblatayn, Uhud, Al-Baqi, the Seven Mosques and Bir Ghars.',
      'There is no required length of stay — the "40 prayers" narration is weak; stay as long as is convenient.'),
  _JourneyStep('🔙', 'Returning home',
      'If you return to Makkah after Madinah before flying home, make Tawaf al-Wida (the farewell tawaf) your final act. Depart from Jeddah or Madinah airport.',
      'Create a "Memories" PDF in the app to keep and share the story of your Umrah.'),
];

class _JourneyTab extends StatelessWidget {
  const _JourneyTab();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _journeySteps.length,
      itemBuilder: (_, i) {
        final s = _journeySteps[i];
        final last = i == _journeySteps.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.emerald, AppColors.emeraldDark]),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(s.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                          width: 2.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: AppColors.gold.withValues(alpha: 0.45)),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${s.title}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15.5)),
                        const SizedBox(height: 6),
                        Text(s.body, style: const TextStyle(height: 1.55)),
                        if (s.tip != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.tips_and_updates_rounded,
                                  size: 16, color: AppColors.gold),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(s.tip!,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7))),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ----------------------------- Faraiz tabs -----------------------------

class _FaraizItem {
  final String title;
  final String detail;
  final String badge; // FARD / WAJIB / NOTE
  const _FaraizItem(this.badge, this.title, this.detail);
}

const _umrahFaraiz = <_FaraizItem>[
  _FaraizItem('FARD', 'Ihram (with the intention, from the miqat)',
      'You must not pass the miqat without ihram. Intention: "Labbayk Allahumma \'Umrah". Restrictions: perfume, cutting hair or nails, (for men) stitched clothing and covering the head, hunting, and quarrelling or indecency.'),
  _FaraizItem('FARD', 'Tawaf — seven circuits',
      'Start at the Black Stone with the Kaaba on your left, in a state of wudu. Afterwards pray two rak\'ahs behind Maqam Ibrahim (or wherever there is space).'),
  _FaraizItem('WAJIB', "Sa'i — seven lengths between Safa and Marwah",
      'Start at Safa; the seventh length ends at Marwah. (Some jurists count it as a pillar.)'),
  _FaraizItem('WAJIB', 'Halq or Taqsir',
      'Men: shaving the whole head is best, or trimming all the hair evenly; women: cut a fingertip\'s length. This releases you from ihram.'),
  _FaraizItem('NOTE', 'No stoning or sacrifice in Umrah',
      'Stoning the Jamarat (Rami) and the sacrifice are rites of Hajj only — they are not part of Umrah.'),
];

const _hajjFaraiz = <_FaraizItem>[
  _FaraizItem('FARD', 'Ihram (intention for Hajj)', 'From the miqat; set off for Mina on 8 Dhul-Hijjah.'),
  _FaraizItem('FARD', 'Standing at Arafah — 9 Dhul-Hijjah',
      '"Hajj is Arafah" (Tirmidhi 889). Be present on the plain of Arafat between midday and sunset; if this is missed, there is no Hajj. Dhuhr and Asr are combined. A day for abundant du\'a.'),
  _FaraizItem('FARD', 'Tawaf al-Ifadah (Tawaf al-Ziyarah)',
      'Tawaf of the Kaaba on 10 Dhul-Hijjah (or during the days of sacrifice) — a pillar of Hajj.'),
  _FaraizItem('WAJIB', 'Staying at Muzdalifah',
      'The night of the 9th–10th under the open sky; Maghrib and Isha are combined here. Collect your pebbles here (around 70).'),
  _FaraizItem('WAJIB', 'Stoning the Jamarat (Rami)',
      '10 Dhul-Hijjah: seven pebbles at the large Jamarah (al-Aqabah) only. Then on the 11th and 12th (and the 13th if you stay): seven pebbles at each of the three Jamarat (small → middle → al-Aqabah), after midday.'),
  _FaraizItem('WAJIB', 'Sacrifice (Hady)',
      'Required for those performing Tamattu\' or Qiran; 10–12 Dhul-Hijjah. Nowadays arranged through official vouchers (Adahi).'),
  _FaraizItem('WAJIB', 'Halq or Taqsir',
      'On 10 Dhul-Hijjah after Rami (and the sacrifice) — the first release from ihram.'),
  _FaraizItem('WAJIB', "Sa'i of Hajj",
      'Performed with Tawaf al-Ifadah (a separate Sa\'i for Hajj in Tamattu\').'),
  _FaraizItem('WAJIB', 'Tawaf al-Wida (farewell tawaf)',
      'The final tawaf before leaving Makkah (not required of women who are menstruating).'),
  _FaraizItem('NOTE', 'If a wajib is missed',
      'Missing a wajib requires a penalty sacrifice (dam); Hajj is not complete without its pillars. Please confirm the details with your scholar or group guide.'),
];

class _FaraizList extends StatelessWidget {
  final List<_FaraizItem> items;
  final String heading;
  const _FaraizList({required this.items, required this.heading});

  Color _badgeColor(String b) => switch (b) {
        'FARD' => Colors.redAccent,
        'WAJIB' => AppColors.gold,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(heading,
            style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
        const SizedBox(height: 12),
        ...items.map((f) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _badgeColor(f.badge).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _badgeColor(f.badge)),
                          ),
                          child: Text(f.badge,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _badgeColor(f.badge))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(f.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(f.detail, style: const TextStyle(height: 1.5)),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _UmrahFaraizTab extends StatelessWidget {
  const _UmrahFaraizTab();
  @override
  Widget build(BuildContext context) => const _FaraizList(
      heading:
          'The pillars and obligations of Umrah (according to the majority of jurists; please confirm with a scholar of your school):',
      items: _umrahFaraiz);
}

class _HajjFaraizTab extends StatelessWidget {
  const _HajjFaraizTab();
  @override
  Widget build(BuildContext context) => const _FaraizList(
      heading:
          'The obligatory (fard) and required (wajib) acts of Hajj, by date (8–13 Dhul-Hijjah). Please ask your guide for detailed rulings:',
      items: _hajjFaraiz);
}
