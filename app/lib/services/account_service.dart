import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'pair_service.dart' show kDefaultPairApiBase;
import 'pair_state.dart';

class AccountResult {
  final bool ok;
  final String? error;
  final Map<String, dynamic> data;
  const AccountResult(this.ok, this.data, [this.error]);
}

/// Optional user account (email + password) on the Umrah Trip website.
/// Guest mode keeps working; when signed in, all trip data, notes,
/// favourites, expenses, settings and the couple pairing are backed up
/// automatically and restored after a reinstall or on a new phone.
class AccountService extends ChangeNotifier {
  final AppState app;
  final PairState pair;
  AccountService(this.app, this.pair);

  String? token;
  String? email;
  String? name;
  String? username;
  DateTime? lastBackupAt;
  bool backingUp = false;
  String? lastError;

  bool get loggedIn => token != null;

  Timer? _debounce;
  String? _lastUploadedHash;

  Uri _ep(String path) =>
      Uri.parse('${pair.api.baseUrl.isEmpty ? kDefaultPairApiBase : pair.api.baseUrl}'
          '/wp-json/umrah-pair/v1/account/$path');

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('acct_token');
    email = p.getString('acct_email');
    name = p.getString('acct_name');
    username = p.getString('acct_username');
    final lb = p.getInt('acct_last_backup');
    lastBackupAt = lb == null ? null : DateTime.fromMillisecondsSinceEpoch(lb);
    app.addListener(_onDataChanged);
    pair.addListener(_onDataChanged);
    notifyListeners();
  }

  @override
  void dispose() {
    app.removeListener(_onDataChanged);
    pair.removeListener(_onDataChanged);
    _debounce?.cancel();
    super.dispose();
  }

  Future<AccountResult> _post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 25)}) async {
    try {
      final r = await http
          .post(_ep(path),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(timeout);
      Map<String, dynamic> j = {};
      try {
        j = jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {
        return AccountResult(false, {}, 'Server HTTP ${r.statusCode} (is plugin v1.3 installed on the website?)');
      }
      if (r.statusCode == 200 && j['ok'] == true) return AccountResult(true, j);
      final msg = j['error'] ?? j['message'] ?? 'HTTP ${r.statusCode}';
      if (r.statusCode == 401 && path != 'login' && path != 'delete') {
        await _clearSession(); // token no longer valid on the server
      }
      return AccountResult(false, j, '$msg');
    } catch (e) {
      return AccountResult(false, {}, 'Internet or server problem: $e');
    }
  }

  Future<void> _saveSession(Map<String, dynamic> j) async {
    token = j['token']?.toString() ?? token;
    email = j['email']?.toString() ?? email;
    name = j['name']?.toString() ?? name;
    if (j.containsKey('username')) username = j['username']?.toString();
    final p = await SharedPreferences.getInstance();
    if (username != null) {
      await p.setString('acct_username', username!);
    } else {
      await p.remove('acct_username');
    }
    if (token != null) await p.setString('acct_token', token!);
    if (email != null) await p.setString('acct_email', email!);
    if (name != null) await p.setString('acct_name', name!);
    notifyListeners();
  }

  Future<void> _clearSession() async {
    token = null;
    email = null;
    name = null;
    username = null;
    lastBackupAt = null;
    _lastUploadedHash = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('acct_token');
    await p.remove('acct_email');
    await p.remove('acct_name');
    await p.remove('acct_username');
    await p.remove('acct_last_backup');
    notifyListeners();
  }

  /// Sets/changes the public @username (and optionally display name).
  Future<AccountResult> updateProfile({String? newUsername, String? newName}) async {
    final r = await _post('profile', {
      'token': token,
      if (newUsername != null) 'username': newUsername,
      if (newName != null) 'name': newName,
    });
    if (r.ok) await _saveSession(r.data);
    return r;
  }

  // ---------------- public API ----------------

  Future<AccountResult> register(String name, String email, String password) async {
    final r = await _post('register',
        {'name': name, 'email': email.trim(), 'password': password});
    if (r.ok) {
      await _saveSession(r.data);
      await backupNow(force: true); // keep whatever is on this phone
    } else {
      lastError = r.error;
      notifyListeners();
    }
    return r;
  }

  /// Logs in. Returns the result; `cloudData` in the result (if any) must
  /// be applied by the caller via [applyCloud] or skipped via [keepLocal].
  Future<AccountResult> login(String email, String password) async {
    final r = await _post('login', {'email': email.trim(), 'password': password});
    if (r.ok) {
      await _saveSession(r.data);
    } else {
      lastError = r.error;
      notifyListeners();
    }
    return r;
  }

  /// Restore the cloud backup into this phone.
  Future<void> applyCloud(Map<String, dynamic> data) async {
    await app.importData(data);
    final p = data['pairing'];
    await pair.importPairing(p is Map ? Map<String, dynamic>.from(p) : null);
    _lastUploadedHash = _hash(_payload());
    _markBackedUp(DateTime.now());
  }

  /// Keep this phone's data and overwrite the cloud copy.
  Future<void> keepLocal() => backupNow(force: true);

  Future<bool> restoreFromCloud() async {
    if (!loggedIn) return false;
    final r = await _post('restore', {'token': token});
    if (!r.ok) {
      lastError = r.error;
      notifyListeners();
      return false;
    }
    final d = r.data['data'];
    if (d is Map) {
      await applyCloud(Map<String, dynamic>.from(d));
      return true;
    }
    lastError = 'There is no cloud backup yet.';
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    final t = token;
    await backupNow(force: true); // last save before leaving
    await _clearSession();
    if (t != null) await _post('logout', {'token': t});
  }

  Future<AccountResult> deleteAccount(String password) async {
    final r = await _post('delete', {'token': token, 'password': password});
    if (r.ok) await _clearSession();
    return r;
  }

  // ---------------- backup ----------------

  Map<String, dynamic> _payload() => {
        ...app.exportData(),
        'pairing': pair.exportPairing(),
      };

  String _hash(Map<String, dynamic> m) => jsonEncode(m).hashCode.toString();

  void _onDataChanged() {
    if (!loggedIn) return;
    // Throttle (not debounce): pairing notifies every few seconds, which
    // would otherwise postpone the backup forever. Unchanged data is
    // skipped by the hash check inside backupNow().
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(const Duration(seconds: 8), () => backupNow());
  }

  Future<bool> backupNow({bool force = false}) async {
    if (!loggedIn || backingUp) return false;
    final payload = _payload();
    final h = _hash(payload);
    if (!force && h == _lastUploadedHash) return true; // nothing changed
    backingUp = true;
    notifyListeners();
    try {
      final r = await _post('backup', {'token': token, 'data': payload});
      if (r.ok) {
        _lastUploadedHash = h;
        lastError = null;
        _markBackedUp(DateTime.now());
      } else {
        lastError = r.error;
      }
      return r.ok;
    } finally {
      backingUp = false;
      notifyListeners();
    }
  }

  void _markBackedUp(DateTime t) {
    lastBackupAt = t;
    SharedPreferences.getInstance()
        .then((p) => p.setInt('acct_last_backup', t.millisecondsSinceEpoch));
    notifyListeners();
  }
}
