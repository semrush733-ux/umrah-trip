import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications_service.dart';
import 'pair_service.dart' show kDefaultPairApiBase;

/// Android only: a small foreground service (like WhatsApp's connection)
/// that keeps checking the website every few seconds while the app is in
/// the background or swiped away, and shows call / message / SOS
/// notifications. Needs no Firebase. iPhone does not allow this.
class BackgroundService {
  static const _channelId = 'umrah_trip_bg';

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      // The ongoing "connected" notification needs its channel first.
      final fln = FlutterLocalNotificationsPlugin();
      await fln
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Background connection',
            description: 'Keeps Umrah Trip connected so calls and messages arrive',
            importance: Importance.low,
            showBadge: false,
          ));
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: umrahBackgroundMain,
          autoStart: true,
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: _channelId,
          initialNotificationTitle: 'Umrah Trip',
          initialNotificationContent: 'Connected — calls & messages will reach you',
          foregroundServiceNotificationId: 7311,
          foregroundServiceTypes: [AndroidForegroundType.remoteMessaging],
        ),
        iosConfiguration: IosConfiguration(autoStart: false, onForeground: umrahBackgroundMain),
      );
      if (!await service.isRunning()) await service.startService();
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

/// Entry point of the background isolate.
@pragma('vm:entry-point')
Future<void> umrahBackgroundMain(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  service.on('stop').listen((_) => service.stopSelf());
  await NotificationsService.instance.init();

  final latest = <String, int>{}; // thread → newest message id seen
  final ringing = <String>{}; // call ids already announced
  var seeded = false;
  var busy = false;

  Future<void> tick() async {
    if (busy) return;
    busy = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload(); // pick up sign-in / pairing changes from the app
      final token = p.getString('acct_token');
      final code = p.getString('pair_code');
      final ptoken = p.getString('pair_token');
      if (token == null && (code == null || ptoken == null)) return;
      final saved = p.getString('pair_base_url');
      final base = (saved != null && saved.startsWith('http')) ? saved : kDefaultPairApiBase;
      // The app shows its own popups while it is on screen.
      final fgAt = p.getInt('app_fg_at') ?? 0;
      final appOnScreen = DateTime.now().millisecondsSinceEpoch - fgAt < 9000;

      final r = await http
          .post(Uri.parse('$base/wp-json/umrah-pair/v1/chat/inbox'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                if (token != null) 'token': token,
                if (code != null && ptoken != null) 'pair_thread': 'pair:$code',
                if (code != null && ptoken != null) 'ptoken': ptoken,
              }))
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(r.body);
      if (j is! Map || j['ok'] != true) return;

      // Incoming calls
      final rings = j['ringing'];
      if (rings is List) {
        for (final c in rings.whereType<Map>()) {
          final id = '${c['call_id']}';
          if (!ringing.add(id) || appOnScreen) continue;
          final video = c['video'] == true;
          await NotificationsService.instance.showPush(
              video ? '📹 ${c['caller_name']}' : '📞 ${c['caller_name']}',
              video ? 'Incoming video call — tap to answer' : 'Incoming voice call — tap to answer',
              call: true);
        }
      }

      // New messages / SOS
      final l = j['latest'];
      if (l is Map) {
        for (final e in l.entries) {
          final m = e.value;
          if (m is! Map) continue;
          final id = int.tryParse('${m['id']}') ?? 0;
          final before = latest['${e.key}'] ?? 0;
          latest['${e.key}'] = id;
          if (!seeded || id <= before || m['mine'] == true || appOnScreen) continue;
          final type = '${m['type']}';
          final name = '${m['name']}';
          if (type == 'call' || type == 'system') continue;
          if (type == 'sos') {
            await NotificationsService.instance
                .showPush('🚨 SOS — $name needs help', 'Tap to see their location', urgent: true);
            continue;
          }
          final body = const {
                'image': '📷 Photo',
                'location': '📍 Location',
                'voice': '🎤 Voice message',
                'meet': '📌 New meeting point',
              }[type] ??
              '${m['body']}';
          await NotificationsService.instance.showPush('💬 $name', body);
        }
      }
      seeded = true;
    } catch (_) {
      // offline — try again next tick
    } finally {
      busy = false;
    }
  }

  await tick();
  Timer.periodic(const Duration(seconds: 6), (_) => tick());
}
