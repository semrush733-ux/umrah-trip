import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';
import 'app_state.dart';
import 'pair_service.dart';

class PartnerInfo {
  final String name;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final DateTime? locAt;
  final bool sharing;
  final DateTime? lastSeen;
  final Map<String, int> visits; // destId -> epoch seconds

  const PartnerInfo({
    required this.name,
    this.lat,
    this.lng,
    this.accuracy,
    this.locAt,
    this.sharing = false,
    this.lastSeen,
    this.visits = const {},
  });
}

class SharedPhoto {
  final String by;
  final String url;
  final String? caption;
  final DateTime at;
  const SharedPhoto({required this.by, required this.url, this.caption, required this.at});
}

/// Couple pairing: one 6-character security code links exactly two devices
/// (e.g. husband + wife). Fully consensual — both sides enter the same code,
/// live location is OFF by default, a visible banner shows while sharing,
/// and either side can stop or un-pair at any time. Foreground-only.
class PairState extends ChangeNotifier {
  final AppState app;
  final PairService api = PairService();

  String? code; // the shared pairing / security code
  String? token; // this device's secret
  String myName = '';
  bool sharingLocation = false;
  bool syncing = false;
  bool uploadingPhoto = false;
  String? lastError;
  DateTime? lastSyncAt;

  PartnerInfo? partner;
  List<SharedPhoto> photos = [];

  Timer? _timer;

  PairState(this.app);

  bool get paired => code != null && token != null;

  Future<void> init() async {
    await api.loadBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    code = prefs.getString('pair_code');
    token = prefs.getString('pair_token');
    myName = prefs.getString('pair_name') ?? '';
    sharingLocation = prefs.getBool('pair_sharing') ?? false;
    notifyListeners();
    if (paired) {
      if (sharingLocation) app.refreshLocation(request: false);
      _startLoop();
    }
  }

  Future<void> setServer(String url) async {
    await api.saveBaseUrl(url);
    notifyListeners();
  }

  Future<String?> createPair(String name) async {
    myName = name;
    final r = await api.create(name);
    if (!r.ok) {
      lastError = r.error;
      notifyListeners();
      return null;
    }
    code = r.data['code'] as String?;
    token = r.data['token'] as String?;
    await _persist();
    _startLoop();
    notifyListeners();
    return code;
  }

  /// For account backup: the pairing credentials of this account.
  Map<String, dynamic>? exportPairing() => paired
      ? {'code': code, 'token': token, 'name': myName}
      : (myName.isNotEmpty ? {'name': myName} : null);

  /// Restores pairing after reinstall + login (only if not already paired).
  Future<void> importPairing(Map<String, dynamic>? p) async {
    if (p == null) return;
    final n = p['name']?.toString();
    if (n != null && n.isNotEmpty) myName = n;
    final c = p['code']?.toString(), t = p['token']?.toString();
    if (!paired && c != null && c.isNotEmpty && t != null && t.isNotEmpty) {
      code = c;
      token = t;
      await _persist();
      _startLoop();
    } else {
      await _persist();
    }
    notifyListeners();
  }

  /// Same-WiFi pairing (server matches both phones by public IP).
  /// Returns the code on success (created or joined), null on failure.
  Future<String?> nearbyPair(String name) async {
    myName = name;
    final r = await api.nearby(name);
    if (!r.ok) {
      lastError = r.error;
      notifyListeners();
      return null;
    }
    code = r.data['code'] as String?;
    token = r.data['token'] as String?;
    await _persist();
    _startLoop();
    notifyListeners();
    return code;
  }

  Future<bool> joinPair(String joinCode, String name) async {
    myName = name;
    final r = await api.join(joinCode.toUpperCase().trim(), name);
    if (!r.ok) {
      lastError = r.error;
      notifyListeners();
      return false;
    }
    code = joinCode.toUpperCase().trim();
    token = r.data['token'] as String?;
    await _persist();
    _startLoop();
    notifyListeners();
    return true;
  }

  Future<void> unpair() async {
    final c = code, t = token;
    _stopLoop();
    code = null;
    token = null;
    partner = null;
    photos = [];
    sharingLocation = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pair_code');
    await prefs.remove('pair_token');
    notifyListeners();
    if (c != null && t != null) await api.unpair(c, t);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (code != null) await prefs.setString('pair_code', code!);
    if (token != null) await prefs.setString('pair_token', token!);
    await prefs.setString('pair_name', myName);
  }

  void setSharing(bool on) {
    sharingLocation = on;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool('pair_sharing', on));
    if (on) {
      // Explicit user action → OK to show the OS permission prompt.
      app.refreshLocation().then((_) => syncNow());
    } else {
      syncNow();
    }
  }

  void _startLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => syncNow());
    syncNow();
  }

  void _stopLoop() {
    _timer?.cancel();
    _timer = null;
  }

  Map<String, int> _myVisits() {
    final out = <String, int>{};
    for (final v in app.planner.visits) {
      if (v.status == VisitStatus.visited) {
        final ts = (v.visitedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
        final prev = out[v.destinationId];
        if (prev == null || ts < prev) out[v.destinationId] = ts;
      }
    }
    return out;
  }

  Future<void> syncNow() async {
    if (!paired || syncing) return;
    syncing = true;
    try {
      if (sharingLocation) await app.refreshLocation(request: false);
      final pos = app.position;
      final r = await api.sync(
        code: code!,
        token: token!,
        lat: sharingLocation ? pos?.latitude : null,
        lng: sharingLocation ? pos?.longitude : null,
        accuracy: sharingLocation ? pos?.accuracy : null,
        sharing: sharingLocation,
        visits: _myVisits(),
      );
      if (!r.ok) {
        lastError = r.error;
      } else {
        lastError = null;
        lastSyncAt = DateTime.now();
        _applyState(r.data);
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void _applyState(Map<String, dynamic> j) {
    final p = j['partner'];
    if (p is Map) {
      final visitsRaw = p['visits'];
      final visits = <String, int>{};
      if (visitsRaw is Map) {
        visitsRaw.forEach((k, v) => visits['$k'] = int.tryParse('$v') ?? 0);
      }
      DateTime? ts(dynamic v) {
        final n = int.tryParse('$v');
        return n == null || n == 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }

      partner = PartnerInfo(
        name: '${p['name'] ?? 'Partner'}',
        lat: double.tryParse('${p['lat']}'),
        lng: double.tryParse('${p['lng']}'),
        accuracy: double.tryParse('${p['acc']}'),
        locAt: ts(p['loc_at']),
        sharing: p['sharing'] == true || '${p['sharing']}' == '1',
        lastSeen: ts(p['last_seen']),
        visits: visits,
      );
    } else {
      partner = null;
    }

    final ph = j['photos'];
    if (ph is List) {
      photos = ph
          .whereType<Map>()
          .map((m) => SharedPhoto(
                by: '${m['by'] ?? ''}',
                url: '${m['url'] ?? ''}',
                caption: m['caption']?.toString(),
                at: DateTime.fromMillisecondsSinceEpoch(
                    (int.tryParse('${m['ts']}') ?? 0) * 1000),
              ))
          .where((p) => p.url.startsWith('http'))
          .toList()
          .reversed
          .toList();
    }
  }

  Future<bool> sendPhoto(Uint8List jpegBytes, {String? caption}) async {
    if (!paired) return false;
    if (jpegBytes.lengthInBytes > 900 * 1024) {
      lastError = 'Photo too large — please pick a smaller one.';
      notifyListeners();
      return false;
    }
    uploadingPhoto = true;
    lastError = null;
    notifyListeners();
    try {
      final r = await api.photo(
        code: code!,
        token: token!,
        base64Jpeg: base64Encode(jpegBytes),
        caption: caption,
      );
      if (r.ok) {
        await syncNow();
      } else {
        lastError = r.error;
      }
      return r.ok;
    } finally {
      uploadingPhoto = false;
      notifyListeners();
    }
  }

  /// Destinations BOTH of us have visited (for the shared experience page).
  Set<String> get bothVisited {
    final mine = _myVisits().keys.toSet();
    final theirs = partner?.visits.keys.toSet() ?? {};
    return mine.intersection(theirs);
  }

  @override
  void dispose() {
    _stopLoop();
    super.dispose();
  }
}
