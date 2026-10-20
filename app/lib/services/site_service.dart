import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';
import 'pair_service.dart' show kDefaultPairApiBase;

class Announcement {
  final String title;
  final String body;
  final int ts;
  const Announcement(this.title, this.body, this.ts);
}

class SponsorPackage {
  final String title;
  final String price;
  final String details;
  const SponsorPackage(this.title, this.price, this.details);
}

/// Talks to the admin panel on the Umrah Trip website (WP plugin v1.1):
///  GET  /config        → whatsapp number, packages, announcement
///  GET  /destinations  → admin-added destinations (merged over the seed)
///  POST /ai            → AI assistant proxy (API key stays on the server)
/// Everything is cached for offline use; the app works fully without it.
class SiteService extends ChangeNotifier {
  String get base => kDefaultPairApiBase;
  Uri _ep(String name) => Uri.parse('$base/wp-json/umrah-pair/v1/$name');

  String whatsapp = '';
  List<SponsorPackage> packages = [];
  Announcement? announcement;
  bool announcementIsNew = false;
  List<Destination> remoteDestinations = [];
  bool aiEnabled = false;

  Future<void> init() async {
    await _loadCache();
    refresh(); // fire-and-forget network refresh
  }

  Future<File> _cacheFile(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name');
  }

  Future<void> _loadCache() async {
    try {
      final cfg = await _cacheFile('site_config.json');
      if (await cfg.exists()) {
        _applyConfig(json.decode(await cfg.readAsString()), persist: false);
      }
      final dst = await _cacheFile('site_destinations.json');
      if (await dst.exists()) {
        _applyDestinations(json.decode(await dst.readAsString()));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final r = await http.get(_ep('config')).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final j = json.decode(r.body) as Map<String, dynamic>;
        if (j['ok'] == true) {
          _applyConfig(j, persist: true);
        }
      }
    } catch (_) {}
    try {
      final r =
          await http.get(_ep('destinations')).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final j = json.decode(r.body) as Map<String, dynamic>;
        if (j['ok'] == true && j['destinations'] is List) {
          _applyDestinations(j['destinations']);
          (await _cacheFile('site_destinations.json'))
              .writeAsString(json.encode(j['destinations']));
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void _applyConfig(Map<String, dynamic> j, {required bool persist}) {
    whatsapp = (j['whatsapp'] ?? '').toString();
    aiEnabled = j['ai_enabled'] == true;
    final pk = j['packages'];
    packages = pk is List
        ? pk
            .whereType<Map>()
            .map((p) => SponsorPackage('${p['title'] ?? ''}',
                '${p['price'] ?? ''}', '${p['details'] ?? ''}'))
            .where((p) => p.title.isNotEmpty)
            .toList()
        : [];
    final an = j['announcement'];
    if (an is Map && '${an['title'] ?? ''}'.isNotEmpty) {
      announcement = Announcement('${an['title']}', '${an['body'] ?? ''}',
          int.tryParse('${an['ts']}') ?? 0);
      _checkAnnouncementNew();
    } else {
      announcement = null;
    }
    if (persist) {
      _cacheFile('site_config.json').then((f) => f.writeAsString(json.encode(j)));
    }
  }

  Future<void> _checkAnnouncementNew() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt('announcement_seen_ts') ?? 0;
    announcementIsNew = (announcement?.ts ?? 0) > seen;
    notifyListeners();
  }

  Future<void> markAnnouncementSeen() async {
    if (announcement == null) return;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('announcement_seen_ts', announcement!.ts);
    announcementIsNew = false;
    notifyListeners();
  }

  void _applyDestinations(dynamic list) {
    if (list is! List) return;
    final out = <Destination>[];
    for (final e in list) {
      try {
        out.add(Destination.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    remoteDestinations = out;
  }

  /// AI assistant via the server-side proxy; the API key never ships in the
  /// app. Returns the answer text, or an error message string.
  Future<String> askAi(String question, {String? context}) async {
    try {
      final r = await http
          .post(_ep('ai'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'question': question,
                if (context != null) 'context': context,
              }))
          .timeout(const Duration(seconds: 60));
      final j = json.decode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 200 && j['ok'] == true) {
        return (j['answer'] ?? '').toString();
      }
      return 'AI error: ${j['error'] ?? 'HTTP ${r.statusCode}'}';
    } catch (e) {
      return 'Network problem — please try again. ($e)';
    }
  }
}
