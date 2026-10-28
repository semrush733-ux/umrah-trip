import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/app_state.dart';
import '../services/site_service.dart';
import '../widgets/destination_card.dart';
import 'ai_screen.dart';
import 'destination_detail.dart';
import 'duas_screen.dart';
import 'friends_screen.dart';
import 'journey_guide_screen.dart';
import 'prayer_qibla_screen.dart';
import 'recommendations_screen.dart';
import 'root.dart';
import 'tasbeeh_screen.dart';
import 'transport_screen.dart';
import 'umrah_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final now = saudiNow();
    final today = DateTime(now.year, now.month, now.day);
    final todayVisits = app.planner.visitsOn(today);
    final next = app.planner.nextPlanned(today);
    final counters = app.planner.counters();
    final nextDest = next == null ? null : app.repo.byId(next.destinationId);
    final dist = nextDest == null ? null : app.distanceKmTo(nextDest);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => app.refreshLocation(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ---- Header: welcome + Saudi time + city ----
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/images/logo.png', width: 44, height: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.welcome,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(
                        '${s.saudiTime}: ${DateFormat('EEE, d MMM · HH:mm').format(now)}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ---- Location / city strip ----
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: AppColors.emerald),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.currentCity,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.55))),
                          Text(
                            app.position != null
                                ? '${s.regionName(app.activeRegion)} · ${app.position!.latitude.toStringAsFixed(4)}, ${app.position!.longitude.toStringAsFixed(4)}'
                                : s.regionName(app.activeRegion),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (app.position == null)
                            Text(s.locationOff,
                                style: const TextStyle(fontSize: 11.5, color: Colors.orange)),
                        ],
                      ),
                    ),
                    if (app.position == null)
                      TextButton(
                        onPressed: () => app.refreshLocation(),
                        child: Text(s.enableLocation),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ---- Announcement from the website admin ----
            Consumer<SiteService>(builder: (context, site, _) {
              final a = site.announcement;
              if (a == null || a.title.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                          left: BorderSide(
                              color: site.announcementIsNew
                                  ? AppColors.gold
                                  : AppColors.emerald,
                              width: 4)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.campaign_rounded,
                            color: site.announcementIsNew
                                ? AppColors.gold
                                : AppColors.emerald),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              if (a.body.isNotEmpty)
                                Text(a.body,
                                    style: const TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        if (site.announcementIsNew)
                          TextButton(
                              onPressed: site.markAnnouncementSeen,
                              child: const Text('OK')),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // ---- Quick actions ----
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.06,
              children: [
                _QuickAction(
                    icon: Icons.forum_rounded,
                    label: 'Chats & Calls',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FriendsScreen()))),
                _QuickAction(
                    icon: Icons.mosque_rounded,
                    label: 'Prayer & Qibla',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PrayerQiblaScreen()))),
                _QuickAction(
                    icon: Icons.menu_book_rounded,
                    label: 'Duas & Azkar',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DuasScreen()))),
                _QuickAction(
                    icon: Icons.touch_app_rounded,
                    label: 'Tasbeeh',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TasbeehScreen()))),
                _QuickAction(
                    icon: Icons.auto_stories_rounded,
                    label: 'Umrah Guide',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const UmrahGuideScreen()))),
                _QuickAction(
                    icon: Icons.directions_car_rounded,
                    label: 'Transport',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TransportScreen()))),
                _QuickAction(
                    icon: Icons.smart_toy_rounded,
                    label: 'AI Assistant',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiScreen()))),
                _QuickAction(
                    icon: Icons.flight_takeoff_rounded,
                    label: 'Journey Guide',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const JourneyGuideScreen()))),
                _QuickAction(
                    icon: Icons.recommend_rounded,
                    label: 'Where to Go',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RecommendationsScreen()))),
                _QuickAction(
                    icon: Icons.rule_rounded,
                    label: 'Faraiz',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            const JourneyGuideScreen(initialTab: 1)))),
              ],
            ),
            const SizedBox(height: 14),

            // ---- My Hotel ----
            Card(
              child: ListTile(
                leading: Icon(Icons.hotel_rounded,
                    color: app.hotelLat != null ? AppColors.gold : AppColors.emerald),
                title: Text(
                    app.hotelLat == null
                        ? 'Save my hotel location'
                        : (app.hotelLabel ?? 'My Hotel'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(app.hotelLat == null
                    ? 'Tap while at your hotel — your way back is always one tap away'
                    : 'Tap: navigate back to hotel · long-press: update/remove'),
                trailing: app.hotelLat == null
                    ? const Icon(Icons.add_location_alt_rounded)
                    : const Icon(Icons.navigation_rounded, color: AppColors.emerald),
                onTap: () => _hotelTap(context, app),
                onLongPress: () => _hotelOptions(context, app),
              ),
            ),
            const SizedBox(height: 14),

            // ---- Counters ----
            Row(
              children: [
                _Counter(label: s.planned, value: counters.planned, color: AppColors.gold),
                const SizedBox(width: 10),
                _Counter(label: s.visited, value: counters.visited, color: Colors.green),
                const SizedBox(width: 10),
                _Counter(label: s.remaining, value: counters.remaining, color: AppColors.emerald),
              ],
            ),
            const SizedBox(height: 18),

            // ---- Next destination hero ----
            if (nextDest != null) ...[
              Text(s.nextDestination,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Card(
                child: Container(
                  decoration: BoxDecoration(gradient: regionGradient(nextDest.region)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(categoryIcon(nextDest), color: AppColors.goldLight, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(nextDest.nameEn,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (next?.time != null) '🕐 ${next!.time}',
                          if (dist != null) '${formatKm(dist)} (${s.straightLine})',
                          if (dist != null && walkingEstimate(dist) != null) walkingEstimate(dist)!,
                        ].join(' · '),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold, foregroundColor: AppColors.slate),
                        onPressed: () => launchNavigation(context, nextDest),
                        icon: const Icon(Icons.navigation_rounded),
                        label: Text(s.startNavigation),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ---- Today's visits ----
            Text(s.todayVisits,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (todayVisits.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, color: AppColors.gold, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(s.planYourNext,
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                      FilledButton(
                        onPressed: () => RootScreen.tabIndex.value = 3,
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        child: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...todayVisits.map((v) {
                final d = app.repo.byId(v.destinationId);
                if (d == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: StatusDot(v.status),
                    title: Text(d.nameEn, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(v.time ?? '—'),
                    trailing: IconButton(
                      icon: const Icon(Icons.navigation_rounded, color: AppColors.emerald),
                      onPressed: () => launchNavigation(context, d),
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DestinationDetailScreen(destination: d))),
                  ),
                );
              }),
            const SizedBox(height: 18),

            // ---- City cards ----
            Text(s.selectCity, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: app.repo.regions.map((r) {
                  final selected = app.activeRegion == r && app.position == null;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => app.setManualRegion(r),
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          gradient: regionGradient(r),
                          borderRadius: BorderRadius.circular(18),
                          border: selected
                              ? Border.all(color: AppColors.gold, width: 2.5)
                              : null,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(regionIcon(r), color: AppColors.goldLight),
                            Text(s.regionName(r),
                                maxLines: 2,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // ---- Nearby ----
            Text(s.nearby, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...app.nearbyDestinations(limit: 5).map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DestinationCard(destination: d, compact: true),
                )),
          ],
        ),
      ),
    );
  }

}

Future<void> _hotelTap(BuildContext context, AppState app) async {
  if (app.hotelLat == null) {
    await _saveHotelHere(context, app);
  } else {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${app.hotelLat},${app.hotelLng}&travelmode=walking');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _saveHotelHere(BuildContext context, AppState app) async {
  await app.refreshLocation();
  final p = app.position;
  if (p == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location is needed — please turn on GPS and try again.')));
    }
    return;
  }
  if (!context.mounted) return;
  final ctrl = TextEditingController(text: app.hotelLabel ?? 'My Hotel');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save hotel here?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)} (±${p.accuracy.toStringAsFixed(0)} m)'),
          const SizedBox(height: 10),
          TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true) {
    await app.setHotel(p.latitude, p.longitude,
        ctrl.text.trim().isEmpty ? 'My Hotel' : ctrl.text.trim());
  }
}

Future<void> _hotelOptions(BuildContext context, AppState app) async {
  if (app.hotelLat == null) return;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.my_location_rounded, color: AppColors.emerald),
            title: const Text('Update to my current location'),
            onTap: () async {
              Navigator.pop(ctx);
              await _saveHotelHere(context, app);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            title: const Text('Remove saved hotel'),
            onTap: () {
              Navigator.pop(ctx);
              app.setHotel(null, null, null);
            },
          ),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.emerald, AppColors.emeraldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.goldLight, size: 24),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Counter({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
