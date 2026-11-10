import 'dart:async';
import 'dart:convert';

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

  /// A notification was tapped while the app runs: its payload kind
  /// (WEEKLY_REVIEW opens the week in chat; anything else opens Now).
  final _opened = StreamController<String>.broadcast();
  Stream<String> get opened => _opened.stream;

  static const nightlyId = 9000;
  static const morningId = 9001;
  static const prepId = 9002;
  static const testId = 9003;

  /// What Ally says on its own (ADR 0027): briefing, slot nudges, wrap-up,
  /// Sunday review. 9100-9119, rescheduled whole from the server's agenda.
  static const agendaBase = 9100;
  static const _agendaSlots = 20;
  static bool isAgendaId(int id) => id >= agendaBase && id < agendaBase + _agendaSlots;
  static const _prefsLevel = 'ally_proactivity';

  /// Ally's peach, used for the small icon and app name in the notification.
  static const _tint = Color(0xFFF6C9B2);

  static const _agendaChannel = AndroidNotificationDetails(
    'ally_proactive',
    'From Ally',
    color: _tint,
    channelDescription: 'Your briefing, nudges for what you planned, and the evening wrap-up',
    importance: Importance.high,
    priority: Priority.high,
    styleInformation: BigTextStyleInformation(''),
  );

  /// Android lets an app hold about 500 alarms; stay well under it.
  static const _maxReminderAlarms = 300;

  /// Exact alarms fire on the minute; inexact ones can be held back by an hour
  /// or more when the phone is idle (and longer on Samsung). Exact needs the
  /// person's OK on Android 12+, so this is checked before every sync.
  bool _exact = false;
  AndroidScheduleMode get _mode =>
      _exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  static const _prefsPaused = 'ally_paused';
  static const _nightlyCategory = 'tonight';
  static const _prefsTime = 'guide_nightly_time';
  static const _prefsMorning = 'guide_morning_time';

  /// Only a starting point for the time picker. Each person chooses their
  /// own time in setup; nothing is scheduled until they do.
  static const suggestedNightlyTime = '21:30';

  static const _channel = AndroidNotificationDetails(
    'habit_reminders',
    'Habit reminders',
    color: _tint,
    channelDescription: 'Daily reminders to log your habits',
    importance: Importance.high,
    priority: Priority.high,
  );

  static AndroidNotificationDetails _nightlyChannel({required bool withActions}) =>
      AndroidNotificationDetails(
        'guide_nightly',
        'Tonight, one thing',
        color: _tint,
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
    await refreshExactMode();
  }

  /// Every scheduled notification goes (signing out: the next account starts clean).
  Future<void> cancelAll() async {
    if (!_ready || kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Whether reminders can fire at the exact minute (Android 12+ asks).
  Future<bool> canScheduleExact() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshExactMode() async => _exact = await canScheduleExact();

  /// Opens Android's "Alarms & reminders" page for Ally.
  Future<void> requestExact() async {
    await _android?.requestExactAlarmsPermission();
    await refreshExactMode();
  }

  /// Whether the phone lets Ally show notifications at all.
  Future<bool> notificationsAllowed() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// How many reminder notifications are waiting on this phone right now.
  Future<int> pendingReminderCount() async {
    if (!_ready || kIsWeb) return 0;
    return (await _plugin.pendingNotificationRequests()).where((p) => (p.id & 0x40000000) != 0).length;
  }

  /// "Send me a test reminder": one notification a minute from now, scheduled
  /// exactly like a real reminder, so the person can see reminders work.
  Future<DateTime?> sendTestReminder() async {
    if (!_ready || kIsWeb) return null;
    await refreshExactMode();
    final at = DateTime.now().add(const Duration(minutes: 1));
    await _schedule(testId, 'Test reminder', 'Reminders are working. This one was set a minute ago.', at);
    return at;
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
      if (p.id != nightlyId && p.id != morningId && p.id != prepId && p.id != testId && !isAgendaId(p.id) && !isReminder) await _plugin.cancel(p.id);
    }
    await _plugin.cancel(prepId);
    // Sick / travelling / on holiday: no habit or prep prompts at all.
    if (await isPaused()) return;
    await _schedulePrep(habits);
    for (final h in habits) {
      final t = _parseTime(h.reminderTime);
      // A habit that has become automatic no longer gets reminders.
      if (t == null || !h.isActive || h.stage == 'AUTOMATIC') continue;
      final counts = h.habitType.toUpperCase() == 'COUNT';
      await _scheduleDaily(
        id: h.id.hashCode & 0x3fffffff, // below the reminder id range
        title: h.title,
        body: counts ? 'Tap +1 each time, right from here.' : 'Time to log this habit.',
        hour: t.$1,
        minute: t.$2,
        // A count habit's reminder carries a +1 button: no need to open the app.
        plusOneFor: counts ? h.id : null,
      );
    }
  }

  /// Sick, travel and holiday mode: Ally sends nothing it started itself.
  Future<bool> isPaused() async => (await _readPref(_prefsPaused)) == '1';

  Future<void> setPaused(bool paused) async {
    await _writePref(_prefsPaused, paused ? '1' : null);
    if (paused) {
      await _plugin.cancel(prepId);
      await _plugin.cancel(nightlyId);
      await _plugin.cancel(morningId);
      for (var i = 0; i < _agendaSlots; i++) {
        await _plugin.cancel(agendaBase + i);
      }
    }
  }

  // Quiet hours: nothing Ally starts lands between 22:30 and 07:00.
  static bool _quiet(int hour, int minute) {
    final m = hour * 60 + minute;
    return m >= 22 * 60 + 30 || m < 7 * 60;
  }

  /// One combined evening prep notification ("soak the oats; pack the gym
  /// bag") at the earliest prep time. One notification for all preps is the
  /// notification budget (nightly + morning + prep = at most 3 a day that
  /// Ally starts). Reminders you asked for are not part of that budget.
  Future<void> _schedulePrep(List<Habit> habits) async {
    final due = <(int, int, String)>[];
    for (final h in habits) {
      final t = _parseTime(h.prepTime);
      final what = h.prepareAhead?.trim();
      if (t == null || !h.isActive || h.stage == 'AUTOMATIC' || what == null || what.isEmpty || _quiet(t.$1, t.$2)) continue;
      due.add((t.$1, t.$2, what));
    }
    if (due.isEmpty) return;
    due.sort((a, b) => (a.$1 * 60 + a.$2).compareTo(b.$1 * 60 + b.$2));
    await _scheduleDaily(
      id: prepId,
      title: 'Prep for tomorrow',
      body: due.map((d) => d.$3).toSet().join('; '),
      hour: due.first.$1,
      minute: due.first.$2,
    );
  }

  // ---- Reminders the person asked for in chat ----

  static int _reminderNotifId(String id) => 0x40000000 | (id.hashCode & 0x3fffffff);

  // The closing nudge of a time window ("between 5 and 7" → again at 6:45).
  static int _windowNotifId(String id) => 0x40000000 | ((id.hashCode ^ 0x2a5a5a5) & 0x3fffffff);

  static const _windowWarnBefore = Duration(minutes: 15);

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails('reminders', 'Reminders',
        color: _tint,
        channelDescription: 'Reminders you asked for',
        importance: Importance.high,
        priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  // A reminder you can answer from the notification: Done (and for the
  // follow-up, In 1 hour / Tomorrow).
  static NotificationDetails _answerable({required bool followUp}) => NotificationDetails(
        android: AndroidNotificationDetails('reminders', 'Reminders',
            color: _tint,
            channelDescription: 'Reminders you asked for',
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              const AndroidNotificationAction('FU_DONE', 'Done'),
              if (followUp) const AndroidNotificationAction('FU_HOUR', 'In 1 hour'),
              if (followUp) const AndroidNotificationAction('FU_TOMORROW', 'Tomorrow'),
            ]),
        iOS: const DarwinNotificationDetails(),
      );

  Future<void> _schedule(int id, String title, String text, DateTime at, {NotificationDetails? details, String? payload}) => _plugin.zonedSchedule(
        id,
        title,
        text,
        tz.TZDateTime.from(at, tz.local),
        details ?? _reminderDetails,
        payload: payload,
        androidScheduleMode: _mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

  // "Did you call mom?" 30 minutes after a reminder nobody answered.
  static int _followUpNotifId(String id) => 0x40000000 | ((id.hashCode ^ 0x5bd1e995) & 0x3fffffff);
  static const _followUpAfter = Duration(minutes: 30);

  static String _reminderPayload(String kind, String id, String text, DateTime at) =>
      jsonEncode({'k': kind, 'id': id, 't': text, 'at': at.toUtc().toIso8601String()});

  Future<bool> _followUpsOn() async => ((await _readPref(_prefsLevel)) ?? 'NORMAL') == 'NORMAL';

  // The 2nd, 3rd… upcoming time of a repeating reminder (the 1st uses _reminderNotifId).
  static int _occurrenceNotifId(String id, int i) => 0x40000000 | ((id.hashCode * 31 + i * 7919) & 0x3fffffff);

  static List<int> _idsFor(Reminder r, int times) => [
        _reminderNotifId(r.id),
        _windowNotifId(r.id),
        _followUpNotifId(r.id),
        for (var i = 1; i < times; i++) _occurrenceNotifId(r.id, i),
      ];

  /// A reminder notifies at [at]. With a [windowEnd] ("sometime between 5 and
  /// 7") it also notifies shortly before the window closes. A repeating
  /// reminder goes through [syncReminders], which schedules its next times
  /// whether or not the last one was ticked.
  Future<void> scheduleReminder(String id, String text, DateTime at, {DateTime? windowEnd, List<DateTime> later = const []}) async {
    if (!_ready || kIsWeb) return;
    final now = DateTime.now();
    if (at.isAfter(now)) {
      await _schedule(_reminderNotifId(id), 'Reminder', text, at,
          details: _answerable(followUp: false), payload: _reminderPayload('REMINDER', id, text, at));
    }
    // One follow-up for the next time, only at Normal (Quieter and Silent: just the reminder).
    final follow = at.add(_followUpAfter);
    if (windowEnd == null && follow.isAfter(now) && await _followUpsOn()) {
      await _schedule(_followUpNotifId(id), 'Did you do it?', text, follow,
          details: _answerable(followUp: true), payload: _reminderPayload('FOLLOWUP', id, text, at));
    } else {
      await _plugin.cancel(_followUpNotifId(id));
    }
    for (var i = 0; i < later.length; i++) {
      if (later[i].isAfter(now)) await _schedule(_occurrenceNotifId(id, i + 1), 'Reminder', text, later[i]);
    }
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
    await _plugin.cancel(_followUpNotifId(id));
    await _plugin.cancel(_windowNotifId(id));
    for (var i = 1; i < 7; i++) {
      await _plugin.cancel(_occurrenceNotifId(id, i));
    }
  }

  /// Makes the phone match the server: schedules every upcoming reminder
  /// (same id → same notification) and cancels ones that no longer exist
  /// (done, undone, or deleted on another device).
  Future<void> syncReminders(List<Reminder> reminders) async {
    if (!_ready || kIsWeb) return;
    await refreshExactMode();
    // With many reminders, fewer upcoming times each, to stay under the alarm limit.
    final times = reminders.isEmpty ? 7 : (_maxReminderAlarms ~/ reminders.length).clamp(1, 7);
    final keep = {for (final r in reminders) ..._idsFor(r, times)};
    for (final p in await _plugin.pendingNotificationRequests()) {
      if ((p.id & 0x40000000) != 0 && !keep.contains(p.id)) await _plugin.cancel(p.id);
    }
    for (final r in reminders) {
      final list = r.occurrences.take(times).toList();
      await scheduleReminder(r.id, r.text, list.isEmpty ? r.remindAt : list.first,
          windowEnd: r.windowEnd, later: list.skip(1).toList());
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
    // Replaced by the agenda's briefing and wrap-up (ADR 0027): the person's
    // nightly time is now the wrap-up time. Old nudges are cleared.
    if (!_ready || kIsWeb) return;
    await _plugin.cancel(nightlyId);
    await _plugin.cancel(morningId);
  }

  // ---- What Ally says on its own (ADR 0027) ----

  /// Schedules the server's agenda as local notifications (replacing the
  /// last one). Works offline once fetched; refreshed on open, after changes,
  /// and hourly in the background.
  Future<void> syncAgenda(Map<String, dynamic> agenda) async {
    if (!_ready || kIsWeb) return;
    await _writePref(_prefsLevel, agenda['level']?.toString() ?? 'NORMAL');
    for (var i = 0; i < _agendaSlots; i++) {
      await _plugin.cancel(agendaBase + i);
    }
    await _plugin.cancel(nightlyId);
    await _plugin.cancel(morningId);
    if (await isPaused()) return;
    final now = DateTime.now();
    var slot = 0;
    for (final raw in (agenda['items'] as List? ?? const [])) {
      if (raw is! Map || slot >= _agendaSlots) continue;
      final at = DateTime.tryParse('${raw['at']}')?.toLocal();
      if (at == null || !at.isAfter(now)) continue;
      final actions = <AndroidNotificationAction>[
        for (final a in (raw['actions'] as List? ?? const []))
          if (a is Map && a['id'] == 'DONE')
            const AndroidNotificationAction('AG_DONE', 'Done')
          else if (a is Map && a['id'] == 'SKIP')
            const AndroidNotificationAction('AG_SKIP', 'Not now')
          else if (a is Map && a['id'] == 'MOVE_LEFT')
            const AndroidNotificationAction('AG_MOVE', 'Move to tomorrow'),
      ];
      await _schedule(
        agendaBase + slot,
        '${raw['title']}',
        '${raw['body']}',
        at,
        details: NotificationDetails(
          android: AndroidNotificationDetails(_agendaChannel.channelId, _agendaChannel.channelName,
              color: _tint,
              channelDescription: _agendaChannel.channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: const BigTextStyleInformation(''),
              actions: actions.isEmpty ? null : actions),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode({
          'k': raw['kind'],
          if (raw['sourceType'] != null) 's': raw['sourceType'],
          if (raw['sourceId'] != null) 'id': raw['sourceId'],
          if (raw['minutes'] != null) 'm': raw['minutes'],
          if (raw['count'] != null) 'c': raw['count'],
        }),
      );
      slot++;
    }
  }

  /// The app was opened by tapping a notification: its kind, once.
  Future<String?> launchKind() async {
    if (!_ready || kIsWeb) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp != true) return null;
    return _kindOf(d!.notificationResponse?.payload);
  }

  static String? _kindOf(String? payload) {
    if (payload == null || !payload.startsWith('{')) return null;
    try {
      return (jsonDecode(payload) as Map)['k']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Done / Not now on a slot nudge, Move to tomorrow on the wrap-up, and
  /// Done / In 1 hour / Tomorrow on a reminder. Shared by the foreground
  /// handler and the background isolate. True when it was one of these.
  Future<bool> handleAllyAction(NotificationResponse r) async {
    final action = r.actionId;
    if (action == null || !(action.startsWith('AG_') || action.startsWith('FU_') || action.startsWith('CT_'))) return false;
    Map<String, dynamic> p;
    try {
      p = Map<String, dynamic>.from(jsonDecode(r.payload ?? '{}') as Map);
    } catch (_) {
      return true;
    }
    final repo = getIt<LifeRepository>();
    final id = p['id']?.toString();
    try {
      switch (action) {
        case 'AG_DONE' || 'AG_SKIP':
          if (id == null) return true;
          await repo.respondNow('${p['s'] ?? 'TASK'}', id, action == 'AG_DONE' ? 'DONE' : 'SKIP',
              minutes: (p['m'] as num?)?.toInt(), count: (p['c'] as num?)?.toInt());
          if (action == 'AG_DONE') {
            await _plugin.show(r.id ?? agendaBase, 'Counted.', 'Nice. The next thing is on Now when you want it.',
                const NotificationDetails(android: _agendaChannel));
          }
        case 'CT_PLUS':
          if (id == null) return true;
          final c = await repo.addCount(id);
          await _plugin.show(r.id ?? agendaBase, '${c['line'] ?? 'Counted.'}', 'Tap +1 again whenever you want.',
              const NotificationDetails(android: _agendaChannel));
        case 'AG_MOVE':
          final m = await repo.wrapUpMove();
          await _plugin.show(r.id ?? agendaBase, 'Done for today', '${m['message'] ?? 'Moved to tomorrow.'}',
              const NotificationDetails(android: _agendaChannel));
        case 'FU_DONE':
          if (id == null) return true;
          await repo.respondNow('TASK', id, 'DONE');
          await _plugin.cancel(_followUpNotifId(id));
        case 'FU_HOUR':
          if (id == null) return true;
          await _schedule(_followUpNotifId(id), 'Reminder', '${p['t'] ?? 'Reminder'}', DateTime.now().add(const Duration(hours: 1)),
              details: _answerable(followUp: true), payload: r.payload);
        case 'FU_TOMORROW':
          if (id == null) return true;
          final at = DateTime.tryParse('${p['at']}') ?? DateTime.now();
          await repo.moveReminder(id, at.add(const Duration(days: 1)));
          await _plugin.cancel(_followUpNotifId(id));
      }
    } on QueuedOfflineException {
      // Saved for when the phone is back online.
    } catch (_) {
      return true;
    }
    // Keep the rest of the day's notifications true to what just changed.
    try {
      await syncAgenda(await repo.agenda());
    } catch (_) {}
    return true;
  }

  Future<void> _onResponse(NotificationResponse r) async {
    if (r.actionId == null) {
      final kind = _kindOf(r.payload);
      if (kind != null) _opened.add(kind);
      return;
    }
    if (await handleAllyAction(r) || await handleNightlyAction(r)) _answered.add(null);
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
    String? plusOneFor,
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
      plusOneFor == null
          ? const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails())
          : const NotificationDetails(
              android: AndroidNotificationDetails('habit_reminders', 'Habit reminders',
                  color: _tint,
                  channelDescription: 'Daily reminders to log your habits',
                  importance: Importance.high,
                  priority: Priority.high,
                  actions: [AndroidNotificationAction('CT_PLUS', '+1')]),
              iOS: DarwinNotificationDetails()),
      androidScheduleMode: _mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      payload: plusOneFor == null ? null : jsonEncode({'k': 'COUNT', 'id': plusOneFor}),
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
  if (!await NotificationService.instance.handleAllyAction(r)) {
    await NotificationService.instance.handleNightlyAction(r);
  }
}
