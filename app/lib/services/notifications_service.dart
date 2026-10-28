import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: visit reminders (30 min before a scheduled ziyarat)
/// and site announcements. All offline/local — no Firebase account needed.
class NotificationsService {
  static final NotificationsService instance = NotificationsService._();
  NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  late tz.Location _ksa;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      _ksa = tz.getLocation('Asia/Riyadh');
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
          const InitializationSettings(android: android, iOS: ios));
      _ready = true;
      // Channels must exist up front so pushes from the website use them.
      final droid = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (droid != null) {
        for (final c in const [
          AndroidNotificationChannel('umrah_trip', 'Umrah Trip',
              description: 'Messages, reminders and announcements', importance: Importance.high),
          AndroidNotificationChannel('umrah_trip_calls', 'Calls',
              description: 'Incoming voice and video calls', importance: Importance.max),
          AndroidNotificationChannel('umrah_trip_sos', 'SOS alerts',
              description: 'Emergency alerts from your partner, family or friends',
              importance: Importance.max),
        ]) {
          try {
            await droid.createNotificationChannel(c);
          } catch (_) {}
        }
      }
    } catch (_) {
      // Notifications are best-effort; the app works fully without them.
    }
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final iosOk = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      final androidOk = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return (iosOk ?? androidOk ?? true);
    } catch (_) {
      return false;
    }
  }

  static const _channel = AndroidNotificationDetails(
    'umrah_trip',
    'Umrah Trip',
    channelDescription: 'Visit reminders and announcements',
    importance: Importance.high,
    priority: Priority.high,
  );

  int _idFor(String key) => key.hashCode & 0x7fffffff;

  /// Schedules "30 minutes before" the visit's date+time in Saudi time
  /// (Asia/Riyadh, per spec). Replaces any previous reminder for the visit.
  Future<void> scheduleVisitReminder({
    required String visitId,
    required String destinationName,
    required DateTime date,
    required String time, // "HH:mm"
  }) async {
    await init();
    if (!_ready) return;
    try {
      final parts = time.split(':');
      final h = int.tryParse(parts[0]) ?? 8;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      var when = tz.TZDateTime(_ksa, date.year, date.month, date.day, h, m)
          .subtract(const Duration(minutes: 30));
      if (when.isBefore(tz.TZDateTime.now(_ksa))) return;
      await _plugin.zonedSchedule(
        _idFor(visitId),
        'Upcoming Ziyarat 🕌',
        '$destinationName at $time — depart soon, insha\'Allah.',
        when,
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelVisitReminder(String visitId) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(_idFor(visitId));
    } catch (_) {}
  }

  static const _callChannel = AndroidNotificationDetails(
    'umrah_trip_calls',
    'Calls',
    channelDescription: 'Incoming voice and video calls',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    fullScreenIntent: true,
    timeoutAfter: 45000,
  );

  /// Has the user allowed notifications? (null = unknown on this platform)
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

  Future<void> showCall(String title, String body) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(_idFor('call'), title, body,
          const NotificationDetails(
              android: _callChannel,
              iOS: DarwinNotificationDetails(
                  presentAlert: true, presentSound: true, presentBanner: true)));
    } catch (_) {}
  }

  static const _sosChannel = AndroidNotificationDetails(
    'umrah_trip_sos',
    'SOS alerts',
    channelDescription: 'Emergency alerts from your partner, family or friends',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
  );

  Future<void> showSos(String title, String body) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(_idFor('sos'), title, body,
          const NotificationDetails(
              android: _sosChannel,
              iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentSound: true,
                  presentBanner: true,
                  interruptionLevel: InterruptionLevel.timeSensitive)));
    } catch (_) {}
  }

  /// Shows a push that arrived from the website while the app was closed.
  Future<void> showPush(String title, String body, {bool urgent = false, bool call = false}) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
          _idFor(call ? 'call' : (urgent ? 'sos' : 'push:$title')),
          title,
          body,
          NotificationDetails(
              android: call ? _callChannel : (urgent ? _sosChannel : _channel),
              iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true)));
    } catch (_) {}
  }

  Future<void> cancelCall() async {
    try {
      await _plugin.cancel(_idFor('call'));
    } catch (_) {}
  }

  Future<void> showAnnouncement(String title, String body) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(_idFor('announcement'), title, body,
          const NotificationDetails(android: _channel));
    } catch (_) {}
  }
}
