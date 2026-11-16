import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/system/system_settings.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../chat/starters.dart';
import '../you/you_page.dart';

/// "Are my reminders going to come?" Shows the three things Android needs
/// (notifications on, exact alarms allowed, battery unrestricted) with a fix
/// for each, the next reminders, and a test reminder a minute from now.
class RemindersCheckScreen extends StatefulWidget {
  const RemindersCheckScreen({super.key});

  @override
  State<RemindersCheckScreen> createState() => _RemindersCheckScreenState();
}

class _RemindersCheckScreenState extends State<RemindersCheckScreen> with WidgetsBindingObserver {
  bool? _notifications;
  bool? _exact;
  bool? _battery;
  int _pending = 0;
  List<Reminder> _reminders = const [];
  bool _loadingReminders = true;
  String? _testNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _loadReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from Android's settings: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final n = NotificationService.instance;
    final results = await Future.wait([n.notificationsAllowed(), n.canScheduleExact(), SystemSettings.isBatteryUnrestricted()]);
    final pending = await n.pendingReminderCount();
    if (!mounted) return;
    setState(() {
      _notifications = results[0];
      _exact = results[1];
      _battery = results[2];
      _pending = pending;
    });
  }

  Future<void> _loadReminders() async {
    try {
      final list = await getIt<LifeRepository>().reminders();
      // The phone matches the server while we're here.
      await NotificationService.instance.syncReminders(list);
      final pending = await NotificationService.instance.pendingReminderCount();
      if (!mounted) return;
      setState(() {
        _reminders = list;
        _pending = pending;
      });
    } catch (_) {
      // Offline: show what's on the phone only.
    } finally {
      if (mounted) setState(() => _loadingReminders = false);
    }
  }

  Future<void> _test() async {
    final at = await NotificationService.instance.sendTestReminder();
    if (!mounted || at == null) return;
    setState(() => _testNote = 'A test reminder will arrive at ${DateFormat('h:mm a').format(at)}. '
        "Lock the phone and wait. If it doesn't come within 2 minutes, fix the items above that aren't ticked.");
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = [
      for (final r in _reminders)
        for (final t in r.occurrences)
          if (t.isAfter(now)) (r, t),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

    return YouPage(
      title: 'Are they arriving?',
      sub: 'Three things Android needs for reminders to reach you.',
      children: (themed, c) => [
        youRows(c, [
          _Check(
            ok: _notifications,
            title: 'Notifications are on',
            fix: 'Turn on',
            why: "Without this Ally can't show anything.",
            onFix: () async {
              await NotificationService.instance.requestPermission();
              await SystemSettings.openAppSettings();
            },
          ),
          _Check(
            ok: _exact,
            title: 'Reminders on the exact minute',
            fix: 'Allow',
            why: 'Otherwise Android may hold a reminder back by an hour.',
            onFix: () async {
              await NotificationService.instance.requestExact();
              await _check();
            },
          ),
          _Check(
            ok: _battery,
            title: 'Battery: Unrestricted',
            fix: 'Fix',
            why: "Samsung's battery saver stops reminders. Choose \"Allow\", or Battery → Unrestricted.",
            onFix: SystemSettings.requestBatteryUnrestricted,
          ),
        ]),
        AllyButton('Send a test reminder', kind: AllyButtonKind.secondary, wide: true, onPressed: _test),
        if (_testNote != null) AllyNote(_testNote!),
        Text('$_pending set on this phone.', style: AllyType.small(color: c.faint)),
        Text('NEXT UP', style: AllyType.eyebrow(color: c.faint)),
        if (_loadingReminders)
          const AllySkeleton(height: 64, radius: Rad.card)
        else if (upcoming.isEmpty)
          Text('No reminders yet. Try saying "remind me at 6 to call Mummy".', style: AllyType.body(color: c.muted))
        else
          youRows(c, [
            for (final (r, t) in upcoming.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.text, style: AllyType.body(color: c.ink)),
                  Text(r.repeats ? '${_when(t)}, repeats' : _when(t), style: AllyType.small(color: c.muted)),
                ]),
              ),
          ]),
        AllyButton('Add a reminder', wide: true, onPressed: () => starterRequest.value = Starter.reminder),
      ],
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final time = DateFormat('h:mm a').format(t);
    if (day == today) return time;
    if (day == today.add(const Duration(days: 1))) return 'Tmrw $time';
    return '${DateFormat('EEE').format(t)} $time';
  }
}

class _Check extends StatelessWidget {
  final bool? ok;
  final String title;
  final String why;
  final String fix;
  final VoidCallback onFix;
  const _Check({required this.ok, required this.title, required this.why, required this.fix, required this.onFix});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x3),
      child: Row(children: [
        Icon(ok == null ? Icons.more_horiz : (ok! ? Icons.check_circle_rounded : Icons.radio_button_unchecked), size: 20, color: ok == true ? c.ink : c.faint),
        const SizedBox(width: Sp.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AllyType.body(color: c.ink)),
            if (ok == false) Text(why, style: AllyType.small(color: c.muted)),
          ]),
        ),
        if (ok == false) AllyButton(fix, kind: AllyButtonKind.ghost, onPressed: onFix),
      ]),
    );
  }
}
