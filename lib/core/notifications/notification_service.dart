import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/habit.dart';

/// Schedules daily local notifications for habits that have a reminderTime.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'habit_reminders',
    'Habit reminders',
    channelDescription: 'Daily reminders to log your habits',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _ready = true;
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Re-syncs all habit reminders: cancels existing and reschedules from the
  /// current habit list.
  Future<void> syncHabitReminders(List<Habit> habits) async {
    if (!_ready || kIsWeb) return;
    await _plugin.cancelAll();
    for (final h in habits) {
      final t = _parseTime(h.reminderTime);
      if (t == null || !h.isActive) continue;
      await _scheduleDaily(
        id: h.id.hashCode & 0x7fffffff,
        title: '⚡ ${h.title}',
        body: 'Time to log this habit and keep your streak alive.',
        hour: t.$1,
        minute: t.$2,
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  (int, int)? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }
}
