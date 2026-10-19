import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../screens/destination_detail.dart';
import '../services/app_state.dart';

/// Premium gradient art per region (licensed photos arrive via the admin
/// panel later; we never ship unlicensed imagery).
LinearGradient regionGradient(String region) {
  switch (region) {
    case 'makkah':
      return const LinearGradient(
          colors: [Color(0xFF086B58), Color(0xFF0B4A3E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'madinah':
      return const LinearGradient(
          colors: [Color(0xFF1E7F6B), Color(0xFF0A5547)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'jeddah':
      return const LinearGradient(
          colors: [Color(0xFF0E6E8C), Color(0xFF0A4C62)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'riyadh':
      return const LinearGradient(
          colors: [Color(0xFF8C6D2F), Color(0xFF5E4717)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'taif':
      return const LinearGradient(
          colors: [Color(0xFF6E3F8C), Color(0xFF45265C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    default:
      return const LinearGradient(
          colors: [Color(0xFF2F6E8C), Color(0xFF1C4556)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
}

IconData regionIcon(String region) => switch (region) {
      'makkah' => Icons.mosque_rounded,
      'madinah' => Icons.mosque_outlined,
      'jeddah' => Icons.water_rounded,
      'riyadh' => Icons.account_balance_rounded,
      'taif' => Icons.terrain_rounded,
      _ => Icons.museum_rounded,
    };

IconData categoryIcon(Destination d) {
  if (d.categories.contains('mosque')) return Icons.mosque_rounded;
  if (d.categories.contains('museum')) return Icons.museum_rounded;
  if (d.categories.contains('nature')) return Icons.terrain_rounded;
  if (d.categories.contains('islamic_historical')) return Icons.auto_stories_rounded;
  return Icons.attractions_rounded;
}

class StatusDot extends StatelessWidget {
  final VisitStatus status;
  const StatusDot(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      VisitStatus.visited => (Colors.green, Icons.check_circle_rounded),
      VisitStatus.planned => (AppColors.gold, Icons.event_rounded),
      VisitStatus.skipped => (Colors.orange, Icons.redo_rounded),
      VisitStatus.notPlanned => (Colors.transparent, null),
    };
    if (icon == null) return const SizedBox.shrink();
    return Icon(icon, color: color, size: 20);
  }
}

class DestinationCard extends StatelessWidget {
  final Destination destination;
  final bool compact;
  const DestinationCard({super.key, required this.destination, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final dist = app.distanceKmTo(destination);
    final status = app.statusOf(destination.id);
    final name = switch (app.language) {
      AppLanguage.ur => destination.nameUr,
      AppLanguage.ar => destination.nameAr,
      _ => destination.nameEn,
    };

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(destination: destination))),
        child: SizedBox(
          height: compact ? 120 : 148,
          child: Row(
            children: [
              // Art panel
              Container(
                width: compact ? 110 : 132,
                decoration: BoxDecoration(gradient: regionGradient(destination.region)),
                child: Stack(
                  children: [
                    Positioned(
                      right: -14,
                      bottom: -14,
                      child: Icon(categoryIcon(destination),
                          size: compact ? 84 : 104,
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    Center(
                      child: Icon(categoryIcon(destination),
                          size: 36, color: AppColors.goldLight),
                    ),
                    if (!destination.verified)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Tooltip(
                          message: s.unverified,
                          child: Icon(Icons.info_outline_rounded,
                              size: 18, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
                            ),
                          ),
                          StatusDot(status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.place_rounded, size: 15, color: AppColors.gold),
                          const SizedBox(width: 4),
                          Text(s.regionName(destination.region),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (dist != null) ...[
                            Icon(Icons.straighten_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 3),
                            Text('${formatKm(dist)} ${s.distanceFromYou}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6))),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
