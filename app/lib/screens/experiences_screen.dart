import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../services/pair_state.dart';

/// Shared Experiences — the couple's combined journey:
/// which Ziyarat each of you has completed (and which you've BOTH done),
/// plus the photos you've sent each other.
class ExperiencesScreen extends StatelessWidget {
  const ExperiencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pair = context.watch<PairState>();
    final partner = pair.partner;

    final mine = <String, int>{};
    for (final v in app.planner.visits) {
      if (v.status.name == 'visited') {
        mine[v.destinationId] =
            (v.visitedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      }
    }
    final theirs = partner?.visits ?? const <String, int>{};
    final allIds = {...mine.keys, ...theirs.keys}.toList()
      ..sort((a, b) {
        final ta = mine[a] ?? theirs[a] ?? 0;
        final tb = mine[b] ?? theirs[b] ?? 0;
        return tb.compareTo(ta);
      });
    final both = pair.bothVisited;

    final myLabel = pair.myName.isEmpty ? 'Me' : pair.myName;
    final partnerLabel = partner?.name ?? 'Partner';

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Experiences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _Stat(label: myLabel, value: mine.length, color: AppColors.emerald),
              const SizedBox(width: 10),
              _Stat(label: partnerLabel, value: theirs.length, color: AppColors.gold),
              const SizedBox(width: 10),
              _Stat(label: 'Both ✓', value: both.length, color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          if (!pair.paired)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Pair your two phones (Profile → Couple Pairing) to see each '
                    'other\'s completed Ziyarat here.'),
              ),
            ),
          if (allIds.isEmpty && pair.paired)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No visits yet — your journey starts soon, insha\'Allah.')),
            ),
          ...allIds.map((id) {
            final d = app.repo.byId(id);
            final name = d?.nameEn ?? id;
            final iDid = mine.containsKey(id);
            final theyDid = theirs.containsKey(id);
            final ts = mine[id] ?? theirs[id];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  both.contains(id)
                      ? Icons.favorite_rounded
                      : Icons.check_circle_rounded,
                  color: both.contains(id) ? Colors.pinkAccent : Colors.green,
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([
                  if (iDid) '$myLabel ✓',
                  if (theyDid) '$partnerLabel ✓',
                  if (ts != null && ts > 0)
                    DateFormat('d MMM').format(
                        DateTime.fromMillisecondsSinceEpoch(ts * 1000)),
                ].join(' · ')),
                trailing: both.contains(id)
                    ? const Text('TOGETHER',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.pinkAccent))
                    : null,
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text('Shared photos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (pair.photos.isEmpty)
            Text('No photos yet — send one from the Pairing page.',
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: pair.photos.length,
              itemBuilder: (_, i) {
                final p = pair.photos[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        p.url,
                        fit: BoxFit.cover,
                        loadingBuilder: (c, w, prog) => prog == null
                            ? w
                            : const ColoredBox(
                                color: Color(0x22000000),
                                child: Center(child: CircularProgressIndicator())),
                        errorBuilder: (c, e, s) => const ColoredBox(
                            color: Color(0x22000000),
                            child: Icon(Icons.broken_image_rounded)),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Text(
                            '${p.by} · ${DateFormat('d MMM HH:mm').format(p.at)}'
                            '${p.caption != null ? '\n${p.caption}' : ''}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text('$value',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}
