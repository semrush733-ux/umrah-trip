import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for messages, calls and SOS alerts.
class NotificationsService {
  static final NotificationsService instance = NotificationsService._();
  NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _msgChannel = AndroidNotificationDetails('volo_messages', 'Messages',
      channelDescription: 'New chat messages', importance: Importance.high, priority: Priority.high);
  static const _callChannel = AndroidNotificationDetails('volo_calls', 'Calls',
      channelDescription: 'Incoming voice and video calls',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      timeoutAfter: 45000);
  static const _sosChannel = AndroidNotificationDetails('volo_sos', 'SOS alerts',
      channelDescription: 'Emergency alerts from your contacts',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true);

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
          requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
      final droid = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (droid != null) {
        for (final c in const [
          AndroidNotificationChannel('volo_messages', 'Messages', importance: Importance.high),
          AndroidNotificationChannel('volo_calls', 'Calls', importance: Importance.max),
          AndroidNotificationChannel('volo_sos', 'SOS alerts', importance: Importance.max),
        ]) {
          try {
            await droid.createNotificationChannel(c);
          } catch (_) {}
        }
      }
      _ready = true;
    } catch (_) {}
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final i = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      final a = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return i ?? a ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> enabled() async {
    await init();
    if (!_ready) return null;
    try {
      final a = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      if (a != null) return a;
      final i = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return i?.isEnabled;
    } catch (_) {
      return null;
    }
  }

  int _id(String k) => k.hashCode & 0x7fffffff;

  Future<void> _show(String key, String title, String body, AndroidNotificationDetails ch) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(_id(key), title, body,
          NotificationDetails(android: ch, iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true)));
    } catch (_) {}
  }

  Future<void> showMessage(String thread, String title, String body) => _show('msg:$thread', title, body, _msgChannel);
  Future<void> showCall(String title, String body) => _show('call', title, body, _callChannel);
  Future<void> showSos(String title, String body) => _show('sos', title, body, _sosChannel);

  /// Used by the background service / push handler.
  Future<void> showPush(String title, String body, {bool urgent = false, bool call = false, String key = ''}) =>
      _show(call ? 'call' : (urgent ? 'sos' : 'msg:${key.isEmpty ? title : key}'), title, body,
          call ? _callChannel : (urgent ? _sosChannel : _msgChannel));

  Future<void> cancelCall() async {
    try {
      await _plugin.cancel(_id('call'));
    } catch (_) {}
  }
}
