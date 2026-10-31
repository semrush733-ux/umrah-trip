import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';

class VoloUser {
  final int id;
  final String name;
  final String phone;
  final String about;
  final String? username;
  final String? avatar;
  final bool online;
  final DateTime? lastSeen;
  final String? email;
  final bool emailVerified;
  const VoloUser({
    required this.id,
    required this.name,
    required this.phone,
    this.about = '',
    this.username,
    this.avatar,
    this.online = false,
    this.lastSeen,
    this.email,
    this.emailVerified = false,
  });

  factory VoloUser.fromJson(Map j) {
    final ls = int.tryParse('${j['last_seen'] ?? 0}') ?? 0;
    final av = (j['avatar'] ?? '').toString();
    return VoloUser(
      id: int.tryParse('${j['id']}') ?? 0,
      name: '${j['name'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      about: '${j['about'] ?? ''}',
      username: (j['username'] ?? '').toString().isEmpty ? null : '${j['username']}',
      avatar: av.isEmpty ? null : av,
      online: j['online'] == true,
      lastSeen: ls > 0 ? DateTime.fromMillisecondsSinceEpoch(ls * 1000) : null,
      email: (j['email'] ?? '').toString().isEmpty ? null : '${j['email']}',
      emailVerified: j['email_verified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'about': about,
        'username': username,
        'avatar': avatar,
        'email': email,
        'email_verified': emailVerified,
      };

  String get displayName => name.isNotEmpty ? name : phone;
}

/// Phone-number account (SMS code), profile and email verification.
class AccountService extends ChangeNotifier {
  String? token;
  VoloUser? me;
  bool requireEmail = true;
  bool ready = false;

  bool get loggedIn => token != null;
  bool get needsProfile => loggedIn && (me == null || me!.name.isEmpty);
  bool get needsEmail => loggedIn && requireEmail && !(me?.emailVerified ?? false);

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('volo_token');
    final raw = p.getString('volo_me');
    if (raw != null) {
      try {
        me = VoloUser.fromJson(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    requireEmail = p.getBool('volo_require_email') ?? true;
    ready = true;
    notifyListeners();
    Api.config().then((c) async {
      if (c != null && c.containsKey('require_email')) {
        requireEmail = c['require_email'] == true;
        await p.setBool('volo_require_email', requireEmail);
        notifyListeners();
      }
    });
    if (token != null) refresh();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (token != null) {
      await p.setString('volo_token', token!);
    } else {
      await p.remove('volo_token');
    }
    if (me != null) {
      await p.setString('volo_me', jsonEncode(me!.toJson()));
    } else {
      await p.remove('volo_me');
    }
    notifyListeners();
  }

  Future<ApiResult> _call(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final r = await Api.post(path, {'token': token, ...body}, timeout: timeout ?? const Duration(seconds: 25));
    if (r.status == 401 && loggedIn && path != 'auth/verify') {
      token = null;
      me = null;
      await _save();
    }
    if (r.ok && r.data['me'] is Map) {
      me = VoloUser.fromJson(r.data['me'] as Map);
      await _save();
    }
    return r;
  }

  // ---- sign in with phone ----

  Future<ApiResult> startPhone(String phone) => Api.post('auth/start', {'phone': phone});

  Future<ApiResult> verifyCode(String phone, String code) async {
    final r = await Api.post('auth/verify', {'phone': phone, 'code': code});
    if (r.ok) {
      token = '${r.data['token']}';
      if (r.data['me'] is Map) me = VoloUser.fromJson(r.data['me'] as Map);
      await _save();
    }
    return r;
  }

  Future<void> refresh() async {
    if (!loggedIn) return;
    await _call('me', {});
  }

  Future<ApiResult> updateProfile({String? name, String? about, String? username}) => _call('profile', {
        if (name != null) 'name': name,
        if (about != null) 'about': about,
        if (username != null) 'username': username,
      });

  Future<ApiResult> setAvatar(Uint8List? jpeg) =>
      _call('profile', {'avatar': jpeg == null ? '' : base64Encode(jpeg)}, timeout: const Duration(seconds: 60));

  Future<ApiResult> sendEmailCode(String email) => _call('email/send', {'email': email});

  Future<ApiResult> verifyEmail(String code) => _call('email/verify', {'code': code});

  Future<void> logout() async {
    final t = token;
    token = null;
    me = null;
    await _save();
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('volo_chat_'))) {
      await p.remove(k);
    }
    if (t != null) Api.post('auth/logout', {'token': t});
  }

  Future<ApiResult> deleteAccount() async {
    final r = await _call('account/delete', {});
    if (r.ok) {
      token = null;
      me = null;
      await _save();
    }
    return r;
  }
}
