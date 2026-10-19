import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/app_state.dart';
import '../widgets/destination_card.dart';
import 'destination_detail.dart';
import 'root.dart';

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
