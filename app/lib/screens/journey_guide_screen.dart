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
  _JourneyStep('🏠', 'Rawangi se pehle (ghar par)',
      'Ghusl karein, 2 nafal parhein, qarz/amanat ada karein aur ghar walon se maafi-salam. Ihram ki chadrein (mard), hawai chappal, zaroori dawaiyan aur documents hand-carry mein rakhein.',
      'Nusuk app par Umrah/Rawdah permits pehle se book kar lein.'),
  _JourneyStep('✈️', 'Flight mein — Miqat se pehle Ihram',
      'Jeddah jane wali flights Miqat (Qarn al-Manazil / Yalamlam) ke upar se guzarti hain. Crew aksar elaan karta hai — us se PEHLE ihram ki chadrein pehen kar niyyat karein: "Labbayk Allahumma \'Umrah", phir Talbiyah shuru.',
      'Asaani ke liye ihram ghar ya airport se pehen lein; niyyat miqat ke qareeb karein.'),
  _JourneyStep('🛬', 'Jeddah Airport',
      'Immigration aur saman ke baad bus/taxi/train se Makkah rawana hon (~1–1.5 ghanta). Talbiyah parhte rahein.',
      'Transport ke liye app ka "Transport" section — Bin-Mukhtar se WhatsApp par request karein.'),
  _JourneyStep('🏨', 'Makkah — Hotel',
      'Check-in kar ke taza dam hon. App mein "My Hotel" par apna hotel save kar lein taake wapsi ka rasta hamesha ek tap par ho.',
      'Umrah ke liye wuzu kar ke nikalen; ihram ki pabandiyan (khushbu, baal/nakhun) yaad rakhein.'),
  _JourneyStep('🕋', 'Tawaf — 7 chakkar',
      'Hajr-e-Aswad ke samne se "Bismillahi Allahu Akbar" kah kar shuru karein, Kaaba ko BAEN hath par rakhein. Mard pehle 3 chakkar mein ramal (tez chaal) aur idtiba (dayan kandha nanga). Rukn-e-Yamani se Hajr-e-Aswad tak: "Rabbana atina fid-dunya hasanah…".',
      'Tawaf ke baad Maqam-e-Ibrahim ke peechhe 2 rakat, phir Zamzam piyen.'),
  _JourneyStep('🏃', "Sa'i — Safa se Marwah 7 phere",
      'Safa par chadh kar Kaaba ki taraf rukh kar ke dua, phir Marwah tak chalen (green lights ke darmiyan mard halki daud). Safa→Marwah = 1 phera; 7van Marwah par khatam.',
      'Sa\'i ke doran koi makhsoos dua fard nahi — apni zaban mein khoob dua karein.'),
  _JourneyStep('✂️', 'Halq / Taqsir — Umrah mukammal!',
      'Mard sar mundwayen (afzal) ya pure sar ke baal barabar katwayen; khawateen ungli ke por ke barabar. Ihram ki pabandiyan khatam. Umrah qubool ho — Ameen!',
      'Marwah ke bahar licensed barber shops hain.'),
  _JourneyStep('🕌', 'Makkah ke din',
      'Nawafil tawaf, Haram mein namazein, aur app ki Makkah list se ziyarat: Jabal-e-Noor, Jabal-e-Saur, Masjid-e-Ayesha (dusri Umrah ka miqat), Jannat-ul-Mualla, Mina-Arafat-Muzdalifah ka drive.',
      'Har jagah "Navigate" ek tap par — aur "Check In" se yaadgar mahfooz karein.'),
  _JourneyStep('🚄', 'Madinah rawangi',
      'Haramain High-Speed train (~2.5 ghante) ya road (~4-5 ghante). Madinah ke liye ihram nahi hota.',
      'Train tickets sar.hhr.sa ya station par; seasons mein pehle se lein.'),
  _JourneyStep('💚', 'Madinah — Masjid-e-Nabawi ﷺ',
      'Masjid-e-Nabawi mein namazein (1 namaz = 1000), Nabi ﷺ ki khidmat mein salam, RAWDAH ke liye Nusuk permit (free). Ziyarat: Quba (Saturday sunnah), Qiblatain, Uhud, Baqi, Saat Masajid, Bir Ghars…',
      'Qayam ki koi muddat lazim nahi — "40 namazon" wali riwayat zaeef hai; jitne din asaani ho.'),
  _JourneyStep('🔙', 'Wapsi',
      'Agar Madinah ke baad Makkah wapas aayen aur phir watan jayen to aakhri kaam Tawaf-e-Wida. Jeddah ya Madinah airport se wapsi.',
      'App ki "Memories" PDF bana kar apna Safar-e-Umrah mehfooz aur share karein.'),
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
  _FaraizItem('FARD', 'Ihram (niyyat ke sath, Miqat se)',
      'Miqat se baghair ihram guzarna mana hai. Niyyat: "Labbayk Allahumma \'Umrah". Pabandiyan: khushbu, baal/nakhun katna, (mard) sila hua libas aur sar dhanpna, shikar, be-hayai o jhagra.'),
  _FaraizItem('FARD', 'Tawaf — 7 chakkar',
      'Hajr-e-Aswad se shuru, Kaaba baen taraf, ba-wuzu. Baad mein 2 rakat Maqam-e-Ibrahim ke peechhe (jahan jagah mile).'),
  _FaraizItem('WAJIB', "Sa'i — Safa↔Marwah 7 phere",
      'Safa se shuru, 7van phera Marwah par khatam. (Baaz fuqaha ke nazdeek rukn.)'),
  _FaraizItem('WAJIB', 'Halq ya Taqsir',
      'Mard: pura sar mundwana afzal, ya sab baal barabar chhote; Khawateen: ungli ke por ke barabar. Is se ihram khatam.'),
  _FaraizItem('NOTE', 'Rami / qurbani Umrah mein NAHI',
      'Kankriyan (Rami) aur qurbani sirf Hajj ke aamaal hain — Umrah mein inka koi taaluq nahi.'),
];

const _hajjFaraiz = <_FaraizItem>[
  _FaraizItem('FARD', 'Ihram (Hajj ki niyyat)', 'Miqat se, 8 Zil-Hajj ko Mina rawangi.'),
  _FaraizItem('FARD', 'Wuquf-e-Arafah — 9 Zil-Hajj',
      '"Hajj Arafah hai" (Tirmidhi 889). Zawal se ghuroob tak maidan-e-Arafat mein hazri; ye chhoot jaye to Hajj nahi hota. Zuhr-Asr jama. Khoob dua ka din.'),
  _FaraizItem('FARD', 'Tawaf-e-Ziyarah',
      '10 Zil-Hajj (ya ayyam-e-nahr mein) Kaaba ka tawaf — Hajj ka rukn.'),
  _FaraizItem('WAJIB', 'Muzdalifah mein qayam',
      '9-10 ki raat khule asman tale; Maghrib-Isha yahan jama. Yahan se kankriyan chunein (ik 70 ke qareeb).'),
  _FaraizItem('WAJIB', 'Rami al-Jamarat (kankriyan)',
      '10 Zil-Hajj: sirf BARI Jamarah (Aqabah) ko 7. Phir 11 aur 12 (aur ruk jayen to 13) Zil-Hajj: teeno jamarat (Sughra→Wusta→Aqabah) ko 7-7, zawal ke baad.'),
  _FaraizItem('WAJIB', 'Qurbani (Hady)',
      'Tamattu/Qiran karne wale par wajib; 10-12 Zil-Hajj. Aaj kal official vouchers (Adahi) se.'),
  _FaraizItem('WAJIB', 'Halq/Taqsir',
      '10 Zil-Hajj Rami (aur qurbani) ke baad — pehla halal hona.'),
  _FaraizItem('WAJIB', "Sa'i-e-Hajj",
      'Tawaf-e-Ziyarah ke sath (Tamattu mein Hajj ka alag Sa\'i).'),
  _FaraizItem('WAJIB', 'Tawaf-e-Wida',
      'Makkah se rukhsati se pehle aakhri tawaf (haiza khawateen par nahi).'),
  _FaraizItem('NOTE', 'Wajib chhootne par',
      'Kisi wajib ke tark par dam (qurbani) lazim aata hai; fard ke baghair Hajj mukammal nahi. Tafseelat apne alim/muallim se.'),
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
          'Umrah ke arkan-o-wajibat (jamhoor fiqh ke mutabiq; apne maslak ke alim se tasdeeq karein):',
      items: _umrahFaraiz);
}

class _HajjFaraizTab extends StatelessWidget {
  const _HajjFaraizTab();
  @override
  Widget build(BuildContext context) => const _FaraizList(
      heading:
          'Hajj ke fard aur wajib aamaal, tareekh-war (8–13 Zil-Hajj). Tafseeli masail apne muallim se:',
      items: _hajjFaraiz);
}
