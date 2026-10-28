import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../widgets/destination_card.dart';
import 'umrah_guide_screen.dart';

const _umrahGuideDestinations = {
  'safa-marwah',
  'masjid-nabawi',
  'masjid-ayesha',
  'abyar-ali',
  'masjid-nimrah',
};

/// One-tap, real navigation: opens Google Maps turn-by-turn directions to the
/// destination's verified coordinates. No simulated routes, ever.
Future<void> launchNavigation(BuildContext context, Destination d,
    {bool apple = false}) async {
  final lat = d.lat.toStringAsFixed(6);
  final lng = d.lng.toStringAsFixed(6);
  final uri = apple
      ? Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d')
      : Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the maps app.')),
    );
  }
}

class DestinationDetailScreen extends StatefulWidget {
  final Destination destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleGuide(AppState app) async {
    final d = widget.destination;
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    final lang = switch (app.language) {
      AppLanguage.ur => 'ur-PK',
      AppLanguage.ar => 'ar-SA',
      _ => 'en-US',
    };
    try {
      await _tts.setLanguage(lang);
    } catch (_) {}
    final text = switch (app.language) {
      AppLanguage.ar => '${d.nameAr}. ${d.summaryEn}. ${d.significance}',
      AppLanguage.ur => '${d.nameUr}. ${d.summaryEn}. ${d.significance}',
      _ => '${d.nameEn}. ${d.summaryEn} ${d.significance}',
    };
    setState(() => _speaking = true);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    await _tts.speak(text);
  }

  Future<void> _addToTrip(AppState app) async {
    final s = S.of(context);
    final days = app.planner.sortedDays;
    TripDay? day;
    if (days.isEmpty) {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: DateTime.now(),
        helpText: s.addDay,
      );
      if (picked == null) return;
      day = await app.addDay(picked, widget.destination.region);
    } else {
      if (!mounted) return;
      day = await showModalBottomSheet<TripDay>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(s.addToTrip,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              ...days.map((d) => ListTile(
                    leading: const Icon(Icons.event_rounded, color: AppColors.emerald),
                    title: Text(
                        '${s.day} ${days.indexOf(d) + 1} · ${d.date.toIso8601String().substring(0, 10)}'),
                    subtitle: Text(s.regionName(d.city)),
                    onTap: () => Navigator.pop(ctx, d),
                  )),
              ListTile(
                leading: const Icon(Icons.add_rounded, color: AppColors.gold),
                title: Text(s.addDay),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: DateTime.now(),
                  );
                  if (picked == null) return;
                  final nd = await app.addDay(picked, widget.destination.region);
                  if (ctx.mounted) Navigator.pop(ctx, nd);
                },
              ),
            ],
          ),
        ),
      );
      if (day == null) return;
    }
    TimeOfDay? t;
    if (mounted) {
      t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    }
    final timeStr = t == null
        ? null
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await app.addVisit(day.id, widget.destination.id, time: timeStr);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s.addToTrip} ✓')));
    }
  }

  Future<void> _checkInHere(AppState app) async {
    final s = S.of(context);
    await app.refreshLocation();
    final p = app.position;
    if (p == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.locationOff)));
      }
      return;
    }
    final d = widget.destination;
    final km = haversineKm(p.latitude, p.longitude, d.lat, d.lng);
    if (!mounted) return;
    final within = km <= 0.5;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.checkInHere),
        content: Text(within
            ? 'You are ${formatKm(km)} from ${d.nameEn}. Mark as visited?'
            : 'You appear to be ${formatKm(km)} away (${s.straightLine}). GPS accuracy: ±${p.accuracy.toStringAsFixed(0)} m. Mark as visited anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.markVisited)),
        ],
      ),
    );
    if (confirmed == true) {
      await app.markVisitedToday(d.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${s.visited} ✓')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final d = widget.destination;
    final dist = app.distanceKmTo(d);
    final status = app.statusOf(d.id);
    final fav = app.isFavorite(d.id);
    final isIOS = !kIsWeb && Platform.isIOS;
    final onSurfaceDim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: regionGradient(d.region)),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      bottom: -30,
                      child: Icon(categoryIcon(d),
                          size: 200, color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nameAr,
                              style: TextStyle(
                                  color: AppColors.goldLight.withValues(alpha: 0.95),
                                  fontSize: 16)),
                          Text(d.nameEn,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15)),
                          const SizedBox(height: 4),
                          Text('${d.nameUr} · ${d.nameRoman}',
                              style:
                                  TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: s.save,
                onPressed: () => app.toggleFavorite(d.id),
                icon: Icon(fav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    color: fav ? AppColors.gold : Colors.white),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status / verification / distance chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: StatusDot(status == VisitStatus.notPlanned
                            ? VisitStatus.planned
                            : status),
                        label: Text(switch (status) {
                          VisitStatus.visited => s.visited,
                          VisitStatus.planned => s.planned,
                          VisitStatus.skipped => s.skipped,
                          VisitStatus.notPlanned => s.notPlanned,
                        }),
                      ),
                      Chip(
                        avatar: Icon(
                            d.verified ? Icons.verified_rounded : Icons.info_outline_rounded,
                            size: 18,
                            color: d.verified ? AppColors.emerald : Colors.orange),
                        label: Text(d.verified
                            ? '${s.verifiedData} · ${d.lastVerified ?? ''}'
                            : s.unverified),
                      ),
                      if (dist != null)
                        Chip(
                          avatar: const Icon(Icons.straighten_rounded, size: 18),
                          label: Text(
                              '${formatKm(dist)} (${s.straightLine})${walkingEstimate(dist) != null ? ' · ${walkingEstimate(dist)}' : ''}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Primary navigation CTA
                  FilledButton.icon(
                    onPressed: () => launchNavigation(context, d),
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(s.startNavigation),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(s.openInMaps,
                        style: TextStyle(fontSize: 12, color: onSurfaceDim)),
                  ),
                  if (isIOS)
                    Center(
                      child: TextButton(
                        onPressed: () => launchNavigation(context, d, apple: true),
                        child: Text(s.appleMaps),
                      ),
                    ),
                  const SizedBox(height: 10),

                  if (d.bookingUrl != null) ...[
                    FilledButton.tonalIcon(
                      onPressed: () => launchUrl(Uri.parse(d.bookingUrl!),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.confirmation_number_rounded),
                      label: Text(
                          'Official permits & booking · ${Uri.parse(d.bookingUrl!).host}'),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                          'Bookings are confirmed only by the official provider.',
                          style: TextStyle(fontSize: 11.5, color: onSurfaceDim)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_umrahGuideDestinations.contains(d.id)) ...[
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const UmrahGuideScreen())),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('Umrah Guide — Ihram · Tawaf · Sa\'i'),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Action row: Add to Trip | Mark Visited | Save
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addToTrip(app),
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(s.addToTrip, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: status == VisitStatus.visited
                              ? null
                              : () => app.markVisitedToday(d.id),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: Text(s.markVisited, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _checkInHere(app),
                          icon: const Icon(Icons.where_to_vote_rounded, size: 18),
                          label: Text(s.checkInHere, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleGuide(app),
                          icon: Icon(_speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                              size: 18),
                          label: Text(s.listenGuide, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // About
                  _SectionTitle(s.details),
                  Text(app.romanUrdu ? d.summaryRoman : d.summaryEn,
                      style: const TextStyle(fontSize: 15.5, height: 1.5)),
                  const SizedBox(height: 16),

                  _SectionTitle(s.history),
                  Text(d.significance, style: const TextStyle(fontSize: 15, height: 1.5)),
                  if (d.historyRefs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...d.historyRefs.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $r',
                              style: TextStyle(fontSize: 13, color: onSurfaceDim)),
                        )),
                  ],
                  const SizedBox(height: 16),

                  // Visit info
                  _SectionTitle(s.visitInfo),
                  _InfoRow(Icons.schedule_rounded, s.hours,
                      '${d.openingHours ?? '—'}${d.hoursVerified ? '' : '  (${s.unverified})'}'),
                  _InfoRow(
                      Icons.payments_rounded,
                      s.entryFee,
                      d.entryFee == null
                          ? '—  (${s.unverified})'
                          : d.entryFee == 0
                              ? '${s.free}${d.feeVerified ? '' : '  (${s.unverified})'}'
                              : '${d.entryFee} SAR${d.feeVerified ? '' : '  (${s.unverified})'}'),
                  _InfoRow(Icons.timer_rounded, s.duration, '~${d.visitDurationMin} min'),
                  if (d.bestTime != null)
                    _InfoRow(Icons.wb_sunny_rounded, s.bestTime, d.bestTime!),
                  if (d.accessibility != null)
                    _InfoRow(Icons.accessible_rounded, 'Accessibility', d.accessibility!),
                  if (d.restrictions != null)
                    _InfoRow(Icons.rule_rounded, 'Restrictions', d.restrictions!),
                  _InfoRow(Icons.gps_fixed_rounded, 'GPS',
                      '${d.lat.toStringAsFixed(5)}, ${d.lng.toStringAsFixed(5)}'),
                  const SizedBox(height: 16),

                  if (d.tips.isNotEmpty) ...[
                    _SectionTitle(s.tips),
                    ...d.tips.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.tips_and_updates_rounded,
                                  size: 17, color: AppColors.gold),
                              const SizedBox(width: 8),
                              Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],

                  // Nearby suggestions — nearest destinations, clickable,
                  // with straight-line distance from THIS place.
                  Builder(builder: (context) {
                    final nearby = app.repo.all
                        .where((o) => o.id != d.id)
                        .toList()
                      ..sort((a, b) => haversineKm(d.lat, d.lng, a.lat, a.lng)
                          .compareTo(haversineKm(d.lat, d.lng, b.lat, b.lng)));
                    final top = nearby.take(5).toList();
                    if (top.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Nearby ziyarat — where next?'),
                        ...top.map((o) {
                          final km = haversineKm(d.lat, d.lng, o.lat, o.lng);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: regionGradient(o.region),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(categoryIcon(o),
                                    color: AppColors.goldLight, size: 20),
                              ),
                              title: Text(o.nameEn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text(
                                  '${formatKm(km)} ${s.straightLine} · ${s.regionName(o.region)}',
                                  style: const TextStyle(fontSize: 11.5)),
                              trailing: IconButton(
                                icon: const Icon(Icons.navigation_rounded,
                                    color: AppColors.emerald, size: 20),
                                onPressed: () => launchNavigation(context, o),
                              ),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => DestinationDetailScreen(
                                          destination: o))),
                            ),
                          );
                        }),
                        if (d.nearby.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              children: d.nearby
                                  .map((n) => Chip(
                                      label: Text(n,
                                          style: const TextStyle(fontSize: 12))))
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),

                  if (d.sourceUrl != null)
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(d.sourceUrl!),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: Text('Source · ${Uri.parse(d.sourceUrl!).host}'),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.emerald),
            const SizedBox(width: 10),
            SizedBox(
                width: 110,
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(child: Text(value, style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}
