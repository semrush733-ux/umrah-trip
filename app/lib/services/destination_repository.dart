import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/destination.dart';

/// Loads the bundled, offline-first destination database.
/// A future sync layer will merge server updates on top of this seed.
class DestinationRepository {
  List<Destination> _all = const [];
  bool get isLoaded => _all.isNotEmpty;
  List<Destination> get all => _all;

  Future<void> load() async {
    if (isLoaded) return;
    final raw = await rootBundle.loadString('assets/data/destinations.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = (data['destinations'] as List)
        .map((e) => Destination.fromJson(e as Map<String, dynamic>))
        .toList();
    _all = List.unmodifiable(list);
  }

  /// Merges admin-added destinations from the website (offline-cached).
  /// Additive and idempotent: seed entries are never overwritten or removed.
  void applyRemote(List<Destination> remote) {
    if (remote.isEmpty) return;
    final ids = _all.map((d) => d.id).toSet();
    final added = remote.where((d) => !ids.contains(d.id)).toList();
    if (added.isEmpty) return;
    _all = List.unmodifiable([..._all, ...added]);
  }

  Destination? byId(String id) {
    for (final d in _all) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<Destination> byRegion(String region) =>
      _all.where((d) => d.region == region).toList();

  List<String> get regions {
    final seen = <String>{};
    final ordered = <String>[];
    for (final d in _all) {
      if (seen.add(d.region)) ordered.add(d.region);
    }
    return ordered;
  }
}
