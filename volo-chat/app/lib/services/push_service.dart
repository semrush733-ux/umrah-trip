import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/api.dart';
import 'account_service.dart';
import 'notifications_service.dart';
import 'social_service.dart';

@pragma('vm:entry-point')
Future<void> voloPushBackgroundHandler(RemoteMessage msg) async {
  final d = msg.data;
  if (d['type'] == 'call') {
    await NotificationsService.instance.showPush('${d['title'] ?? 'Incoming call'}', '${d['body'] ?? 'Open Volo Chat to answer'}', call: true);
  }
}

/// Optional Firebase push — switches on only when the admin has entered
/// Firebase keys on the website (no app rebuild needed).
class PushService {
  final AccountService account;
  final SocialService social;
  PushService(this.account, this.social);
  String? _fcm;
  String _sent = '';

  Future<void> init() async {
    try {
      final c = await Api.config();
      final fb = c?['firebase'];
      if (fb is! Map) return;
      final appId = '${Platform.isIOS ? fb['ios_app_id'] : fb['android_app_id']}';
      if (appId.isEmpty || appId == 'null') return;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: FirebaseOptions(
                apiKey: '${fb['api_key']}', appId: appId, messagingSenderId: '${fb['sender_id']}', projectId: '${fb['project_id']}'));
      }
      FirebaseMessaging.onBackgroundMessage(voloPushBackgroundHandler);
      final m = FirebaseMessaging.instance;
      await m.requestPermission(alert: true, badge: true, sound: true);
      await m.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
      FirebaseMessaging.onMessage.listen((_) => social.refreshInbox());
      FirebaseMessaging.onMessageOpenedApp.listen((_) => social.refreshInbox());
      m.onTokenRefresh.listen((t) {
        _fcm = t;
        _register();
      });
      _fcm = await m.getToken();
      account.addListener(_register);
      await _register();
    } catch (e) {
      debugPrint('Push disabled: $e');
    }
  }

  Future<void> _register() async {
    final f = _fcm;
    if (f == null || !account.loggedIn) return;
    final sig = '$f|${account.token}';
    if (sig == _sent) return;
    _sent = sig;
    final r = await Api.post('push/register', {'token': account.token, 'fcm': f, 'platform': Platform.isIOS ? 'ios' : 'android'});
    if (!r.ok) _sent = '';
  }
}
