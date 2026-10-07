import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/chat.dart';
import '../../data/models/habit.dart';
import '../../data/models/tonight.dart';
import '../../data/repositories/life_repository.dart';
import '../api/api_client.dart' show QueuedOfflineException;
import '../api/api_exception.dart';
import '../di/service_locator.dart';

/// Local notifications: daily habit reminders, and the guide's nightly nudge
/// ("tonight, one thing") which can be answered from the notification itself.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Fires after the user answers the nudge while the app is running, so the
  /// Tonight screen can refresh.
  final _answered = StreamController<void>.broadcast();
  Stream<void> get answered => _answered.stream;

  static const nightlyId = 9000;
  static const morningId = 9001;
  static const _nightlyCategory = 'tonight';
  static const _prefsTime = 'guide_nightly_time';
  static const _prefsMorning = 'guide_morning_time';

  /// Only a starting point for the time picker. Each person chooses their
  /// own time in setup; nothing is scheduled until they do.
  static const suggestedNightlyTime = '21:30';

  static const _channel = AndroidNotificationDetails(
    'habit_reminders',
    'Habit reminders',
    channelDescription: 'Daily reminders to log your habits',
    importance: Importance.high,
    priority: Priority.high,
  );

  static AndroidNotificationDetails _nightlyChannel({required bool withActions}) =>
      AndroidNotificationDetails(
        'guide_nightly',
        'Tonight, one thing',
        channelDescription: "The guide's nightly nudge",
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: const BigTextStyleInformation(''),
        actions: withActions
            ? const [
                AndroidNotificationAction('DONE', 'Done'),
                AndroidNotificationAction('MINIMUM', 'Did the minimum'),
                AndroidNotificationAction(
                  'SKIPPED',
                  'Not tonight',
                  inputs: [AndroidNotificationActionInput(label: 'What got in the way?')],
                ),
              ]
            : null,
      );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tz.initializeTimeZones();
    // Anchor tz.local to the device zone so daily reminders fire at the user's
    // local wall-clock time (without this tz.local defaults to UTC).
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      if (name.isNotEmpty) tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Leave tz.local at its default if the lookup fails.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(notificationCategories: [
      DarwinNotificationCategory(_nightlyCategory, actions: [
        DarwinNotificationAction.plain('DONE', 'Done'),
        DarwinNotificationAction.plain('MINIMUM', 'Did the minimum'),
        DarwinNotificationAction.text('SKIPPED', 'Not tonight',
            buttonTitle: 'Send', placeholder: 'What got in the way?'),
      ]),
    ]);
    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: nightlyNotificationBackground,
    );
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

  /// Re-syncs all habit reminders: cancels existing ones and reschedules from
  /// the current habit list. Never touches the nightly nudge.
  Future<void> syncHabitReminders(List<Habit> habits) async {
    if (!_ready || kIsWeb) return;
    for (final p in await _plugin.pendingNotificationRequests()) {
      final isReminder = (p.id & 0x40000000) != 0;
      if (p.id != nightlyId && p.id != morningId && !isReminder) await _plugin.cancel(p.id);
    }
    for (final h in habits) {
      final t = _parseTime(h.reminderTime);
      if (t == null || !h.isActive) continue;
      await _scheduleDaily(
        id: h.id.hashCode & 0x3fffffff, // below the reminder id range
        title: h.title,
        body: 'Time to log this habit.',
        hour: t.$1,
        minute: t.$2,
      );
    }
  }

  // ---- Reminders the person asked for in chat ----

  static int _reminderNotifId(String id) => 0x40000000 | (id.hashCode & 0x3fffffff);

  // The closing nudge of a time window ("between 5 and 7" → again at 6:45).
  static int _windowNotifId(String id) => 0x40000000 | ((id.hashCode ^ 0x2a5a5a5) & 0x3fffffff);

  static const _windowWarnBefore = Duration(minutes: 15);

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails('reminders', 'Reminders',
        channelDescription: 'Reminders you asked for',
        importance: Importance.high,
        priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _schedule(int id, String title, String text, DateTime at) => _plugin.zonedSchedule(
        id,
        title,
        text,
        tz.TZDateTime.from(at, tz.local),
        _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

  /// A reminder notifies at [at]. With a [windowEnd] ("sometime between 5 and
  /// 7") it also notifies shortly before the window closes. Repeating
  /// reminders need nothing extra: the server creates the next occurrence
  /// when one is done, and [syncReminders] schedules it.
  Future<void> scheduleReminder(String id, String text, DateTime at, {DateTime? windowEnd}) async {
    if (!_ready || kIsWeb) return;
    final now = DateTime.now();
    if (at.isAfter(now)) await _schedule(_reminderNotifId(id), 'Reminder', text, at);
    if (windowEnd != null) {
      final warn = windowEnd.subtract(_windowWarnBefore);
      final when = warn.isAfter(at) ? warn : windowEnd;
      if (when.isAfter(now)) {
        await _schedule(_windowNotifId(id), 'Still open until ${DateFormat('h:mm a').format(windowEnd)}', text, when);
      }
    }
  }

  Future<void> cancelReminder(String id) async {
    await _plugin.cancel(_reminderNotifId(id));
    await _plugin.cancel(_windowNotifId(id));
  }

  /// Makes the phone match the server: schedules every upcoming reminder
  /// (same id → same notification) and cancels ones that no longer exist
  /// (done, undone, or deleted on another device).
  Future<void> syncReminders(List<Reminder> reminders) async {
    if (!_ready || kIsWeb) return;
    final keep = {
      for (final r in reminders) ...[_reminderNotifId(r.id), _windowNotifId(r.id)],
    };
    for (final p in await _plugin.pendingNotificationRequests()) {
      if ((p.id & 0x40000000) != 0 && !keep.contains(p.id)) await _plugin.cancel(p.id);
    }
    for (final r in reminders) {
      await scheduleReminder(r.id, r.text, r.remindAt, windowEnd: r.windowEnd);
    }
  }

  // ---- Nightly nudge ----

  /// The person's own free-time slot, or null before they've chosen one.
  Future<String?> nightlyTime() => _readPref(_prefsTime);

  /// Optional morning heads-up ("tonight's one thing is…"), null when off.
  Future<String?> morningTime() => _readPref(_prefsMorning);

  /// Null turns the nightly nudge off. Nudges are opt-in: nothing is ever
  /// scheduled unless the person set a time here (in setup or by asking in chat).
  Future<void> setNightlyTime(String? hhmm) => _writePref(_prefsTime, hhmm);

  Future<void> setMorningTime(String? hhmm) => _writePref(_prefsMorning, hhmm);

  Future<String?> _readPref(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePref(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    value == null ? await prefs.remove(key) : await prefs.setString(key, value);
  }

  /// Schedules the next nudge from tonight's state. A pending pick goes out
  /// at the nightly time with its title and answer buttons; once answered
  /// (or with nothing picked yet), tomorrow gets a plain "it's ready" nudge
  /// that opens the app, where the next pick is made.
  Future<void> scheduleNightly(Tonight tonight) async {
    if (!_ready || kIsWeb) return;
    await _scheduleMorning(tonight);
    final t = _parseTime(await nightlyTime());
    if (t == null) {
      await _plugin.cancel(nightlyId);
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.$1, t.$2);
    final c = tonight.commitment;
    final pendingTonight = c != null && c.isPending && when.isAfter(now);

    await _plugin.cancel(nightlyId);
    if (pendingTonight) {
      await _plugin.zonedSchedule(
        nightlyId,
        c.isSmaller ? 'Just the minimum tonight' : 'Tonight, one thing',
        c.isSmaller ? c.minimum : '${c.title}\nMinimum: ${c.minimum}',
        when,
        NotificationDetails(
          android: _nightlyChannel(withActions: true),
          iOS: const DarwinNotificationDetails(categoryIdentifier: _nightlyCategory),
        ),
        payload: c.date,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    }
    if (!when.isAfter(now) || (c != null && !c.isPending)) {
      when = when.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      nightlyId,
      'Tonight, one thing',
      "Your next step is ready. It takes 2 minutes to start.",
      when,
      NotificationDetails(android: _nightlyChannel(withActions: false)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Morning heads-up so the evening isn't a surprise. Shows today's pick
  /// when one exists, otherwise a plain reminder for tomorrow morning.
  Future<void> _scheduleMorning(Tonight tonight) async {
    await _plugin.cancel(morningId);
    final t = _parseTime(await morningTime());
    if (t == null) return;
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.$1, t.$2);
    final c = tonight.commitment;
    final today = c != null && c.isPending && when.isAfter(now);
    if (!today && !when.isAfter(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      morningId,
      today ? "Today's one thing" : 'Your one thing for today is ready',
      today ? '${c.title}\nMinimum: ${c.minimum}' : 'Open Ally to see it.',
      when,
      NotificationDetails(android: _nightlyChannel(withActions: false)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _onResponse(NotificationResponse r) async {
    if (await handleNightlyAction(r)) _answered.add(null);
  }

  /// Answers the nudge from its buttons. Returns true when an answer was
  /// sent. Shared by the foreground handler and the background isolate.
  Future<bool> handleNightlyAction(NotificationResponse r) async {
    final action = r.actionId;
    if (action == null || !const {'DONE', 'MINIMUM', 'SKIPPED'}.contains(action)) {
      return false;
    }
    final repo = getIt<LifeRepository>();
    try {
      await repo.guideRespond(action, reason: r.input, date: r.payload, source: 'NOTIFICATION');
    } on ApiException catch (e) {
      // Queued offline still counts as answered; anything else failed.
      if (e is! QueuedOfflineException) return false;
    } catch (_) {
      return false;
    }
    await _plugin.show(
      nightlyId,
      switch (action) {
        'DONE' => 'Counted.',
        'MINIMUM' => 'The minimum counts.',
        _ => 'Okay. No guilt.',
      },
      switch (action) {
        'DONE' => "That's a follow-through day. Tomorrow I'll have the next one.",
        'MINIMUM' => 'You started, and starting is the hard part.',
        _ => "Tomorrow's version will be easier to start.",
      },
      NotificationDetails(android: _nightlyChannel(withActions: false)),
    );
    return true;
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

/// Notification-button answers while the app is closed. Runs in a background
/// isolate with no access to the main isolate's `getIt`, so it wires its own.
@pragma('vm:entry-point')
Future<void> nightlyNotificationBackground(NotificationResponse r) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!getIt.isRegistered<LifeRepository>()) await setupLocator();
  await NotificationService.instance.init();
  await NotificationService.instance.handleNightlyAction(r);
}
