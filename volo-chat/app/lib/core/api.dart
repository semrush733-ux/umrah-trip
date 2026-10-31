import 'dart:convert';

import 'package:http/http.dart' as http;

/// The Volo Chat server (WordPress + "BWP Volo Chat" plugin).
/// Override at build time with --dart-define=VOLO_API_BASE=https://your-site
const String _envBase = String.fromEnvironment('VOLO_API_BASE');
const String kVoloApiBase = _envBase == '' ? 'https://umrahtrip.sbs' : _envBase;

class ApiResult {
  final bool ok;
  final Map<String, dynamic> data;
  final String? error;
  final int status;
  const ApiResult(this.ok, this.data, [this.error, this.status = 0]);
}

class Api {
  static Uri ep(String path) => Uri.parse('$kVoloApiBase/wp-json/volo/v1/$path');

  static Future<ApiResult> post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 20)}) async {
    try {
      final r = await http
          .post(ep(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
      Map<String, dynamic> j;
      try {
        j = jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {
        return ApiResult(false, {}, 'Server error ${r.statusCode} — is the Volo Chat plugin installed?', r.statusCode);
      }
      if (r.statusCode == 200 && j['ok'] == true) return ApiResult(true, j, null, 200);
      return ApiResult(false, j, '${j['error'] ?? j['message'] ?? 'HTTP ${r.statusCode}'}', r.statusCode);
    } catch (e) {
      return ApiResult(false, {}, 'No internet connection or the server is not reachable.');
    }
  }

  static Future<Map<String, dynamic>?> config() async {
    try {
      final r = await http.get(ep('config')).timeout(const Duration(seconds: 12));
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }
}
