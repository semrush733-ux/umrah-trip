import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// REST client for the "BWP Umrah Pair" WordPress plugin
/// (see wordpress-plugin/ in this repo — install it on any WP site).
///
/// The pairing server is fixed to the official Umrah Trip site and hidden
/// from the UI. It can still be overridden at build time with
///   --dart-define=PAIR_API_BASE=https://other-site.com
const String kDefaultPairApiBase = String.fromEnvironment(
  'PAIR_API_BASE',
  defaultValue: 'https://umrahtrip.sbs',
);

class PairApiResult {
  final bool ok;
  final Map<String, dynamic> data;
  final String? error;
  const PairApiResult(this.ok, this.data, [this.error]);
}

class PairService {
  final http.Client _client = http.Client();
  String baseUrl = '';

  Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pair_base_url');
    baseUrl = (saved != null && saved.startsWith('http')) ? saved : kDefaultPairApiBase;
  }

  Future<void> saveBaseUrl(String url) async {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    (await SharedPreferences.getInstance()).setString('pair_base_url', baseUrl);
  }

  bool get configured => baseUrl.startsWith('http');

  Uri _ep(String name) => Uri.parse('$baseUrl/wp-json/umrah-pair/v1/$name');

  Future<PairApiResult> _post(String name, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (!configured) return const PairApiResult(false, {}, 'Server URL not set');
    try {
      final r = await _client
          .post(_ep(name),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(timeout);
      Map<String, dynamic> j = {};
      try {
        j = r.body.isEmpty
            ? {}
            : (jsonDecode(r.body) as Map<String, dynamic>? ?? {});
      } catch (_) {
        // Server (or a firewall) returned non-JSON — surface what it said.
        final snippet = r.body.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
        return PairApiResult(false, {},
            'Server HTTP ${r.statusCode}: ${snippet.substring(0, snippet.length > 120 ? 120 : snippet.length)}');
      }
      if (r.statusCode == 200 && (j['ok'] == true)) {
        return PairApiResult(true, j);
      }
      return PairApiResult(false, j, j['error']?.toString() ?? 'HTTP ${r.statusCode}');
    } catch (e) {
      // Default server: if https is unreachable (e.g. SSL not yet installed),
      // fall back to http once and remember the working scheme.
      if (baseUrl == 'https://umrahtrip.sbs') {
        baseUrl = 'http://umrahtrip.sbs';
        final retry = await _post(name, body, timeout: timeout);
        if (retry.ok) {
          (await SharedPreferences.getInstance())
              .setString('pair_base_url', baseUrl);
          return retry;
        }
        baseUrl = 'https://umrahtrip.sbs';
      }
      return PairApiResult(false, {}, 'Network: $e');
    }
  }

  /// Creates a pair room. Returns {code, token}.
  Future<PairApiResult> create(String name) => _post('create', {'name': name});

  /// Joins with the partner's code. Returns {token}.
  Future<PairApiResult> join(String code, String name) =>
      _post('join', {'code': code, 'name': name});

  /// Same-WiFi pairing: both phones tap the same button; the server matches
  /// devices arriving from the same public IP within a 2-minute window.
  /// Returns {code, token, created, members}.
  Future<PairApiResult> nearby(String name) => _post('nearby', {'name': name});

  /// Heartbeat + fetch in one call. Sends my live location (when sharing) and
  /// my visited map; returns the full merged room state.
  Future<PairApiResult> sync({
    required String code,
    required String token,
    double? lat,
    double? lng,
    double? accuracy,
    required bool sharing,
    required Map<String, int> visits, // destId -> epoch seconds
  }) =>
      _post('sync', {
        'code': code,
        'token': token,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (accuracy != null) 'acc': accuracy,
        'sharing': sharing,
        'visits': visits,
      });

  /// Uploads a photo (base64 jpeg) to the shared gallery. Returns {url}.
  Future<PairApiResult> photo({
    required String code,
    required String token,
    required String base64Jpeg,
    String? caption,
  }) =>
      _post(
          'photo',
          {
            'code': code,
            'token': token,
            'image': base64Jpeg,
            if (caption != null && caption.isNotEmpty) 'caption': caption,
          },
          timeout: const Duration(seconds: 45));

  Future<PairApiResult> unpair(String code, String token) =>
      _post('unpair', {'code': code, 'token': token});
}
