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

  Future<void> showAnnouncement(String title, String body) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(_idFor('announcement'), title, body,
          const NotificationDetails(android: _channel));
    } catch (_) {}
  }
}
