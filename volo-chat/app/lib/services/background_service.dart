import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import 'notifications_service.dart';

/// Android: keeps Volo Chat connected in the background (like WhatsApp) so
/// calls, messages and SOS alerts arrive with the app closed. No Firebase.
class BackgroundService {
  static const _channelId = 'volo_connection';

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(_channelId, 'Connection',
              description: 'Keeps Volo Chat connected so calls and messages arrive',
              importance: Importance.low,
              showBadge: false));
      final s = FlutterBackgroundService();
      await s.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: voloBackgroundMain,
          autoStart: true,
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: _channelId,
          initialNotificationTitle: 'Volo Chat',
          initialNotificationContent: 'Connected',
          foregroundServiceNotificationId: 7420,
          foregroundServiceTypes: [AndroidForegroundType.remoteMessaging],
        ),
        iosConfiguration: IosConfiguration(autoStart: false, onForeground: voloBackgroundMain),
      );
      if (!await s.isRunning()) await s.startService();
    } catch (e) {
      debugPrint('Background service not started: $e');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      final s = FlutterBackgroundService();
      if (await s.isRunning()) s.invoke('stop');
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> voloBackgroundMain(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  service.on('stop').listen((_) => service.stopSelf());
  await NotificationsService.instance.init();
  final latest = <String, int>{};
  final rang = <String>{};
  var seeded = false;
  var busy = false;

  Future<void> tick() async {
    if (busy) return;
    busy = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final token = p.getString('volo_token');
      if (token == null) return;
      final onScreen = DateTime.now().millisecondsSinceEpoch - (p.getInt('volo_fg_at') ?? 0) < 9000;
      final r = await http
          .post(Api.ep('chat/inbox'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'token': token}))
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(r.body);
      if (j is! Map || j['ok'] != true) return;
      final rings = j['ringing'];
      if (rings is List) {
        for (final c in rings.whereType<Map>()) {
          if (!rang.add('${c['call_id']}') || onScreen) continue;
          final video = c['video'] == true;
          await NotificationsService.instance.showPush(
              '${video ? '📹' : '📞'} ${c['caller_name']}', video ? 'Incoming video call — tap to answer' : 'Incoming voice call — tap to answer',
              call: true);
        }
      }
      final l = j['latest'];
      if (l is Map) {
        for (final e in l.entries) {
          final m = e.value;
          if (m is! Map) continue;
          final id = int.tryParse('${m['id']}') ?? 0;
          final before = latest['${e.key}'] ?? 0;
          latest['${e.key}'] = id;
          if (!seeded || id <= before || m['mine'] == true || onScreen) continue;
          final type = '${m['type']}';
          if (type == 'call' || type == 'system' || type == 'deleted') continue;
          final name = '${m['name']}';
          if (type == 'sos') {
            await NotificationsService.instance.showPush('🚨 SOS — $name needs help', 'Tap to see their location', urgent: true);
            continue;
          }
          final b = m['body'];
          final text = type == 'reply' && b is Map
              ? '${b['text']}'
              : const {
                    'image': '📷 Photo',
                    'location': '📍 Location',
                    'voice': '🎤 Voice message',
                    'meet': '📌 Meeting point',
                  }[type] ??
                  '$b';
          await NotificationsService.instance.showPush(name, text, key: '${e.key}');
        }
      }
      seeded = true;
    } catch (_) {
    } finally {
      busy = false;
    }
  }

  await tick();
  Timer.periodic(const Duration(seconds: 6), (_) => tick());
}
