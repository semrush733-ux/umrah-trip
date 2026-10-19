import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../widgets/destination_card.dart';
import 'destination_detail.dart';

/// Date-wise smart trip planner: unlimited days, multiple timed visits per
/// day, drag-and-drop reorder, status tracking, and a "suggest order" helper
/// that never overrides user-fixed times — it only proposes.
class TripScreen extends StatelessWidget {
  const TripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final days = app.planner.sortedDays;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.myTrip,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () => _addDay(context, app),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(s.addDay),
                ),
              ],
            ),
          ),
          Expanded(
            child: days.isEmpty
                ? _EmptyTrip(onAdd: () => _addDay(context, app))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: days.length,
                    itemBuilder: (_, i) => _DayCard(day: days[i], index: i),
                  ),
          ),
        ],
      ),
    );
  }

  static Future<void> _addDay(BuildContext context, AppState app) async {
    final s = S.of(context);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
      helpText: '${s.addDay} (${s.saudiTime})',
    );
    if (picked == null || !context.mounted) return;
    final region = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: app
              .repo.regions
              .map((r) => ListTile(
                    leading: Icon(regionIcon(r), color: AppColors.emerald),
                    title: Text(s.regionName(r)),
                    onTap: () => Navigator.pop(ctx, r),
                  ))
              .toList(),
        ),
      ),
    );
    if (region == null) return;
    await app.addDay(picked, region);
  }
}

class _EmptyTrip extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTrip({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/logo.png', width: 120),
          const SizedBox(height: 14),
          Text(s.planYourNext, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(s.addDay),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final TripDay day;
  final int index;
  const _DayCard({required this.day, required this.index});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final visits = app.planner.visitsOf(day.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: regionGradient(day.city),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${s.day} ${index + 1}',
                      style:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEE, d MMM yyyy').format(day.date),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.regionName(day.city), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await app.removeDay(day.id);
                    } else if (v == 'suggest') {
                      await _suggestOrder(context, app);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'suggest',
                        child: Row(children: [
                          const Icon(Icons.auto_awesome_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('Plan best route (${s.straightLine})'),
                        ])),
                    PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(s.delete),
                        ])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (visits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(s.planYourNext,
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: visits.length,
                onReorder: (a, b) => app.reorder(day.id, a, b),
                itemBuilder: (_, i) {
                  final v = visits[i];
                  final d = app.repo.byId(v.destinationId);
                  return _VisitTile(
                      key: ValueKey(v.id), visit: v, destination: d, index: i, dayId: day.id);
                },
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _addVisit(context, app),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.addVisit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addVisit(BuildContext context, AppState app) async {
    final s = S.of(context);
    final dest = await showModalBottomSheet<Destination>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(builder: (ctx, setState) {
          final list = app.repo.all
              .where((d) => d.matches(q))
              .toList()
            ..sort((a, b) {
              final ar = a.region == day.city ? 0 : 1;
              final br = b.region == day.city ? 0 : 1;
              return ar.compareTo(br);
            });
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        autofocus: false,
                        onChanged: (v) => setState(() => q = v),
                        decoration: InputDecoration(
                          hintText: s.searchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final d = list[i];
                          return ListTile(
                            leading: Icon(categoryIcon(d), color: AppColors.emerald),
                            title: Text(d.nameEn),
                            subtitle: Text(s.regionName(d.region)),
                            onTap: () => Navigator.pop(ctx, d),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
    if (dest == null || !context.mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    final timeStr = t == null
        ? null
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await app.addVisit(day.id, dest.id, time: timeStr);
  }

  Future<void> _suggestOrder(BuildContext context, AppState app) async {
    final s = S.of(context);
    final start = app.position;
    final startLat = start?.latitude ?? app.repo.byRegion(day.city).firstOrNull?.lat ?? 21.42;
    final startLng = start?.longitude ?? app.repo.byRegion(day.city).firstOrNull?.lng ?? 39.82;
    final ordered = app.planner.suggestOrder(day.id,
        startLat: startLat,
        startLng: startLng,
        coordsOf: (id) {
          final d = app.repo.byId(id);
          return (lat: d?.lat ?? startLat, lng: d?.lng ?? startLng);
        });
    if (ordered.isEmpty || !context.mounted) return;

    double total = 0;
    var curLat = startLat, curLng = startLng;
    final lines = <String>[];
    for (var i = 0; i < ordered.length; i++) {
      final d = app.repo.byId(ordered[i].destinationId);
      if (d == null) continue;
      final leg = haversineKm(curLat, curLng, d.lat, d.lng);
      total += leg;
      lines.add('${i + 1}. ${d.nameEn}  (+${formatKm(leg)})');
      curLat = d.lat;
      curLng = d.lng;
    }

    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suggested order'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4), child: Text(l))),
              const SizedBox(height: 8),
              Text('Total ≈ ${formatKm(total)} (${s.straightLine} — not a road route)',
                  style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 4),
              const Text(
                'Suggestion only — your fixed times and order stay yours. Open navigation per stop for real road routing.',
                style: TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.ok)),
        ],
      ),
    );
    if (apply == true) {
      for (var target = 0; target < ordered.length; target++) {
        final current = app.planner.visitsOf(day.id);
        final from = current.indexWhere((v) => v.id == ordered[target].id);
        if (from != -1 && from != target) {
          await app.reorder(day.id, from, target > from ? target + 1 : target);
        }
      }
    }
  }
}

class _VisitTile extends StatelessWidget {
  final TripVisit visit;
  final Destination? destination;
  final int index;
  final String dayId;
  const _VisitTile(
      {super.key,
      required this.visit,
      required this.destination,
      required this.index,
      required this.dayId});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = S.of(context);
    final d = destination;
    if (d == null) return const SizedBox.shrink();

    return Dismissible(
      key: ValueKey('dis-${visit.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.red.withValues(alpha: 0.85),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => app.removeVisit(visit.id),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_indicator_rounded),
        ),
        title: Text(d.nameEn,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration:
                  visit.status == VisitStatus.visited ? TextDecoration.lineThrough : null,
            )),
        subtitle: Text(visit.time ?? '—'),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DestinationDetailScreen(destination: d))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: s.hours,
              icon: const Icon(Icons.schedule_rounded, size: 20),
              onPressed: () async {
                final t = await showTimePicker(
                    context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                if (t != null) {
                  await app.setVisitTime(visit.id,
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                }
              },
            ),
            PopupMenuButton<VisitStatus>(
              tooltip: s.markVisited,
              icon: StatusDot(visit.status),
              onSelected: (st) => app.setStatus(visit.id, st, attachCheckin: st == VisitStatus.visited),
              itemBuilder: (_) => [
                PopupMenuItem(value: VisitStatus.planned, child: Text(s.planned)),
                PopupMenuItem(value: VisitStatus.visited, child: Text(s.markVisited)),
                PopupMenuItem(value: VisitStatus.skipped, child: Text(s.skipped)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
