import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'account_service.dart';
import 'notifications_service.dart';
import 'pair_service.dart' show kDefaultPairApiBase;
import 'pair_state.dart';
import 'social_service.dart';

/// Runs in a background isolate when a push arrives while the app is closed.
/// Chat/SOS pushes are shown by the system itself; calls arrive as data-only
/// messages so we ring with our own full-screen "incoming call" notification.
@pragma('vm:entry-point')
Future<void> umrahPushBackgroundHandler(RemoteMessage msg) async {
  final d = msg.data;
  if (d['type'] == 'call') {
    await NotificationsService.instance.showPush(
        '${d['title'] ?? 'Incoming call'}', '${d['body'] ?? 'Open Umrah Trip to answer'}',
        call: true);
  }
}

/// Push notifications through Firebase Cloud Messaging. Entirely optional:
/// it switches itself on only when the website admin has entered the
/// Firebase keys (Settings → Umrah Trip App), so no app rebuild is needed.
class PushService {
  final AccountService account;
  final PairState pair;
  final SocialService social;
  PushService(this.account, this.pair, this.social);

  bool enabled = false;
  String? _fcm;
  String _lastRegistered = '';

  String get _base => pair.api.baseUrl.isEmpty ? kDefaultPairApiBase : pair.api.baseUrl;

  Future<void> init() async {
    try {
      final r = await http
          .get(Uri.parse('$_base/wp-json/umrah-pair/v1/config'))
          .timeout(const Duration(seconds: 12));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final fb = j['firebase'];
      if (fb is! Map) return; // not configured on the website
      final appId = '${Platform.isIOS ? fb['ios_app_id'] : fb['android_app_id']}';
      if (appId.isEmpty || appId == 'null') return;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: FirebaseOptions(
          apiKey: '${fb['api_key']}',
          appId: appId,
          messagingSenderId: '${fb['sender_id']}',
          projectId: '${fb['project_id']}',
        ));
      }
      FirebaseMessaging.onBackgroundMessage(umrahPushBackgroundHandler);
      final m = FirebaseMessaging.instance;
      await m.requestPermission(alert: true, badge: true, sound: true);
      await m.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
      // App open: our own polling shows calls/chats — just check right away.
      FirebaseMessaging.onMessage.listen((_) => social.refreshInbox());
      FirebaseMessaging.onMessageOpenedApp.listen((_) => social.refreshInbox());
      final initial = await m.getInitialMessage();
      if (initial != null) social.refreshInbox();
      m.onTokenRefresh.listen((t) {
        _fcm = t;
        _register(force: true);
      });
      _fcm = await m.getToken();
      enabled = _fcm != null;
      account.addListener(_register);
      pair.addListener(_register);
      await _register(force: true);
    } catch (e) {
      // iPhone without an Apple push certificate, no Google Play services, etc.
      debugPrint('Push disabled: $e');
    }
  }

  Future<void> _register({bool force = false}) async {
    final fcm = _fcm;
    if (fcm == null) return;
    final sig = '$fcm|${account.token}|${pair.code}|${pair.token}';
    if (!force && sig == _lastRegistered) return;
    if (!account.loggedIn && !pair.paired) return;
    _lastRegistered = sig;
    try {
      await http
          .post(Uri.parse('$_base/wp-json/umrah-pair/v1/push/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'fcm': fcm,
                'platform': Platform.isIOS ? 'ios' : 'android',
                if (account.loggedIn) 'token': account.token,
                if (pair.paired) 'pair_code': pair.code,
                if (pair.paired) 'ptoken': pair.token,
              }))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      _lastRegistered = '';
    }
  }
}
