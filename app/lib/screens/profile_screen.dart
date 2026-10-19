import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../services/app_state.dart';
import '../services/pair_state.dart';
import '../widgets/destination_card.dart';
import 'expenses_screen.dart';
import 'experiences_screen.dart';
import 'memories_screen.dart';
import 'pair_screen.dart';
import 'sponsor_screen.dart';

/// Guest-first profile: settings, language (EN/UR/AR + RTL), dark mode,
/// Roman Urdu toggle, saved places, memories and budget. No forced sign-up.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final favs =
        app.repo.all.where((d) => app.favorites.contains(d.id)).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/images/logo.png', width: 64, height: 64),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.profile,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const Text('Guest · Umrah Trip', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Language
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.language,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                  SegmentedButton<AppLanguage>(
                    segments: AppLanguage.values
                        .map((l) => ButtonSegment(value: l, label: Text(l.label)))
                        .toList(),
                    selected: {app.language},
                    onSelectionChanged: (v) => app.setLanguage(v.first),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.romanUrdu),
                    value: app.romanUrdu,
                    onChanged: app.setRomanUrdu,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Theme
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_rounded, color: AppColors.emerald),
              title: Text(s.darkMode),
              value: app.themeMode == ThemeMode.dark ||
                  (app.themeMode == ThemeMode.system &&
                      MediaQuery.platformBrightnessOf(context) == Brightness.dark),
              onChanged: (v) => app.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          const SizedBox(height: 12),

          // Couple pairing + shared experiences + sponsor
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                      context.watch<PairState>().sharingLocation
                          ? Icons.share_location_rounded
                          : Icons.favorite_rounded,
                      color: context.watch<PairState>().sharingLocation
                          ? Colors.redAccent
                          : Colors.pinkAccent),
                  title: const Text('Couple Pairing'),
                  subtitle: Text(context.watch<PairState>().paired
                      ? (context.watch<PairState>().sharingLocation
                          ? 'Paired · sharing live location'
                          : 'Paired · code ${context.watch<PairState>().code}')
                      : 'Link two phones with one security code'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const PairScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
                  title: const Text('Shared Experiences'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExperiencesScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: ClipOval(
                    child: Image.asset('assets/images/sponsor_binmukhtar.png',
                        width: 28, height: 28),
                  ),
                  title: const Text('Sponsored by Bin-Mukhtar Travels'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SponsorScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_album_rounded, color: AppColors.gold),
                  title: Text(s.memories),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const MemoriesScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.emerald),
                  title: Text(s.budget),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(s.favorites,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (favs.isEmpty)
            Text('—',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))
          else
            ...favs.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DestinationCard(destination: d, compact: true),
                )),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Umrah Trip v0.1.0 · by BWP Experts\nGuest mode · no account required · location used only on demand',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }
}
