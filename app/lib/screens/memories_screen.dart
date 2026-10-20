import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../services/report_service.dart';

/// Full visit history: every visited place with date, time, optional GPS
/// check-in and personal notes. Status can be changed or undone here.
class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final visited = app.planner.visits
        .where((v) => v.status == VisitStatus.visited)
        .toList()
      ..sort((a, b) => (b.visitedAt ?? DateTime(0)).compareTo(a.visitedAt ?? DateTime(0)));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.memories),
        actions: [
          IconButton(
            tooltip: 'Share PDF "Safar-e-Umrah"',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed:
                visited.isEmpty ? null : () => ReportService.shareMemoriesReport(app),
          ),
        ],
      ),
      body: visited.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_album_outlined, size: 56, color: AppColors.gold),
                  const SizedBox(height: 10),
                  Text(s.planYourNext),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visited.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final v = visited[i];
                final d = app.repo.byId(v.destinationId);
                if (d == null) return const SizedBox.shrink();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(d.nameEn,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 16)),
                            ),
                            TextButton(
                              onPressed: () =>
                                  app.setStatus(v.id, VisitStatus.planned),
                              child: Text(s.undo),
                            ),
                          ],
                        ),
                        if (v.visitedAt != null)
                          Text(DateFormat('EEE, d MMM yyyy · HH:mm').format(v.visitedAt!),
                              style: const TextStyle(fontSize: 12.5)),
                        if (v.checkinLat != null)
                          Text(
                              'Check-in: ${v.checkinLat!.toStringAsFixed(5)}, ${v.checkinLng!.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: v.notes ?? '',
                          decoration: InputDecoration(
                            labelText: s.notes,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                          maxLines: 2,
                          onFieldSubmitted: (txt) => app.setVisitNotes(v.id, txt),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
