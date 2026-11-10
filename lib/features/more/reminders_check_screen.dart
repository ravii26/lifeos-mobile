import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/system/system_settings.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';

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

    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
        children: [
          Text('Reminders', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
          const SizedBox(height: 16),
          if (_loadingReminders)
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Loading…', style: G.text(18, color: G.muted)))
          else if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No reminders yet. Try saying "remind me at 6 to call Mummy".', style: G.text(19, color: G.muted, height: 1.4)),
            )
          else
            for (final (r, t) in upcoming.take(8))
              Container(
                constraints: const BoxConstraints(minHeight: 70),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.lineSoft))),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.text, style: G.text(20, height: 1.25)),
                  const SizedBox(height: 2),
                  Text(r.repeats ? '${_when(t)}, repeats' : _when(t), style: G.text(15, color: G.muted, height: 1.25)),
                ]),
              ),
          const SizedBox(height: 18),
          GPill('Add a reminder', primary: true, onTap: () => starterRequest.value = Starter.reminder),
          const SizedBox(height: 26),
          Text('Make sure they arrive', style: G.text(16, color: G.muted, height: 1.2)),
          const SizedBox(height: 4),
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
            last: true,
          ),
          const SizedBox(height: 20),
          GPill('Send a test reminder', onTap: _test),
          if (_testNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_testNote!, style: G.text(16, color: G.muted, height: 1.4)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('$_pending set on this phone.', style: G.text(15, color: G.muted, height: 1.3)),
          ),
        ],
      ),
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
  final bool last;
  const _Check({required this.ok, required this.title, required this.why, required this.fix, required this.onFix, this.last = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: G.lineSoft, width: 0.5),
            bottom: last ? BorderSide(color: G.lineSoft, width: 0.5) : BorderSide.none,
          ),
        ),
        child: Row(children: [
          Icon(
            ok == null ? Icons.more_horiz : (ok! ? Icons.check_circle : Icons.radio_button_unchecked),
            size: 20,
            color: ok == true ? G.good : G.faint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: G.text(17, height: 1.3)),
              if (ok == false)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(why, style: G.text(15, color: G.muted, height: 1.35))),
            ]),
          ),
          if (ok == false)
            TextButton(
              onPressed: onFix,
              style: TextButton.styleFrom(minimumSize: const Size(56, 44)),
              child: Text(fix, style: G.text(16, w: FontWeight.w600, color: G.accent, height: 1.2)),
            ),
        ]),
      );
}
