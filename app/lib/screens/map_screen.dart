import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../widgets/destination_card.dart';
import 'destination_detail.dart';

/// Live map of Saudi Arabia with all verified destination markers, the user's
/// real position, and status-aware marker colours.
///
/// The Google Maps API key is supplied at build time:
///   flutter build apk --dart-define=MAPS_API_KEY=xxxx
/// Without a key we show a setup card instead of a broken/blank map — and
/// one-tap external navigation keeps working regardless.
const String kMapsApiKey = String.fromEnvironment('MAPS_API_KEY');

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  String _filter = 'all'; // all | region keys | planned | visited | nearby

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<Destination> _filtered(AppState app) {
    final all = app.repo.all;
    switch (_filter) {
      case 'planned':
        return all.where((d) => app.statusOf(d.id) == VisitStatus.planned).toList();
      case 'visited':
        return all.where((d) => app.statusOf(d.id) == VisitStatus.visited).toList();
      case 'nearby':
        return app.nearbyDestinations(limit: 8);
      case 'all':
        return all;
      default:
        return all.where((d) => d.region == _filter).toList();
    }
  }

  double _hueFor(AppState app, Destination d) {
    final st = app.statusOf(d.id);
    return switch (st) {
      VisitStatus.visited => BitmapDescriptor.hueGreen,
      VisitStatus.planned => BitmapDescriptor.hueYellow,
      VisitStatus.skipped => BitmapDescriptor.hueOrange,
      VisitStatus.notPlanned => BitmapDescriptor.hueRed,
    };
  }

  void _openPreview(Destination d) {
    final app = context.read<AppState>();
    final s = S.of(context);
    final dist = app.distanceKmTo(d);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        gradient: regionGradient(d.region),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(categoryIcon(d), color: AppColors.goldLight),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.nameEn,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text(
                            '${s.regionName(d.region)}${dist != null ? ' · ${formatKm(dist)} (${s.straightLine})' : ''}',
                            style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(d.summaryEn, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        launchNavigation(context, d);
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(s.navigate),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DestinationDetailScreen(destination: d)));
                    },
                    child: Text(s.details),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final list = _filtered(app);

    final filters = <(String, String)>[
      ('all', s.all),
      ...app.repo.regions.map((r) => (r, s.regionName(r))),
      ('planned', s.planned),
      ('visited', s.visited),
      ('nearby', s.nearby),
    ];

    Widget chips = SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters
            .map((f) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilterChip(
                    label: Text(f.$2),
                    selected: _filter == f.$1,
                    onSelected: (_) => setState(() => _filter = f.$1),
                  ),
                ))
            .toList(),
      ),
    );

    if (kMapsApiKey.isEmpty) {
      // Honest fallback: setup card + distance-aware list. No fake map tiles.
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(s.map,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded, color: AppColors.gold, size: 30),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s.mapsKeyMissing)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            chips,
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => DestinationCard(destination: list[i], compact: true),
              ),
            ),
          ],
        ),
      );
    }

    final markers = list
        .map((d) => Marker(
              markerId: MarkerId(d.id),
              position: LatLng(d.lat, d.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(app, d)),
              infoWindow: InfoWindow(title: d.nameEn),
              onTap: () => _openPreview(d),
            ))
        .toSet();

    final center = app.position != null
        ? LatLng(app.position!.latitude, app.position!.longitude)
        : const LatLng(23.8859, 45.0792); // Saudi Arabia centroid

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: app.position != null ? 11 : 5.3),
          markers: markers,
          myLocationEnabled: app.position != null,
          myLocationButtonEnabled: true,
          onMapCreated: (c) => _controller = c,
        ),
        SafeArea(child: Padding(padding: const EdgeInsets.only(top: 8), child: chips)),
      ],
    );
  }
}
