import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart' show placesRefresh;
import 'you_page.dart';

/// Reminders: what is coming, each one changeable, done or let go, with Undo.
/// The delivery check (permissions, battery saver) is one tap away.
class RemindersPage extends StatefulWidget {
  final LifeRepository repo;

  /// Opens the delivery check; null hides the link (tests).
  final VoidCallback? onCheckDelivery;
  final DateTime Function()? clock;

  const RemindersPage({super.key, required this.repo, this.onCheckDelivery, this.clock});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Reminder>? _items;
  String? _error;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repo.reminders();
      r.sort((a, b) => a.remindAt.compareTo(b.remindAt));
      if (mounted) {
        setState(() {
          _items = r;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _items == null) setState(() => _error = e.message);
    }
  }

  /// The phone schedules reminders itself; it follows every change. Best effort.
  Future<void> _sync() async {
    try {
      await NotificationService.instance.syncReminders(await widget.repo.reminders());
    } catch (_) {}
  }

  Future<void> _act(BuildContext themed, Future<String?> Function() run, String done, {Future<void> Function()? undoLocal}) async {
    try {
      final id = await run();
      placesRefresh.value++;
      await _load();
      await _sync();
      if (!themed.mounted) return;
      showAllyToast(themed, done,
          onUndo: id == null && undoLocal == null
              ? null
              : () async {
                  try {
                    if (id != null) {
                      await widget.repo.undo(id);
                    } else {
                      await undoLocal!();
                    }
                    placesRefresh.value++;
                    await _load();
                    await _sync();
                  } on ApiException catch (e) {
                    if (themed.mounted) showAllyToast(themed, e.message);
                  }
                });
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  Future<void> _open(BuildContext themed, Reminder r) async {
    final choice = await showAllySheet<String>(
      themed,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(r.text, style: AllyType.h2(color: ctx.ac.ink)),
        const SizedBox(height: Sp.x1),
        Text('${dayHeading(r.remindAt, _now)}, ${hm(r.remindAt)}${r.repeats ? ' · repeats' : ''}', style: AllyType.body(color: ctx.ac.muted)),
        const SizedBox(height: Sp.x4),
        AllyButton('Done', wide: true, icon: Icons.check_rounded, onPressed: () => Navigator.of(ctx).pop('done')),
        const SizedBox(height: Sp.x2),
        AllyButton('Change the time', kind: AllyButtonKind.secondary, wide: true, onPressed: () => Navigator.of(ctx).pop('time')),
        AllyButton("Let it go", kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(ctx).pop('letgo')),
      ]),
    );
    if (choice == null || !themed.mounted) return;
    switch (choice) {
      case 'done':
        await _act(themed, () => widget.repo.respondNow('TASK', r.id, 'DONE'), 'Done: ${r.text}');
      case 'letgo':
        await _act(themed, () async => (await widget.repo.letGoStep(r.id)).activityId, 'Let go of ${r.text}.');
      case 'time':
        final day = await showDatePicker(
          context: themed,
          firstDate: DateTime(_now.year, _now.month, _now.day),
          lastDate: _now.add(const Duration(days: 730)),
          initialDate: r.remindAt.isBefore(_now) ? _now : r.remindAt,
        );
        if (day == null || !themed.mounted) return;
        final t = await showTimePicker(context: themed, initialTime: TimeOfDay.fromDateTime(r.remindAt));
        if (t == null || !themed.mounted) return;
        final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (!at.isAfter(_now)) {
          showAllyToast(themed, 'Pick a time that has not passed yet.');
          return;
        }
        final before = r.remindAt;
        await _act(themed, () async {
          await widget.repo.moveReminder(r.id, at);
          return null;
        }, 'Moved to ${dayHeading(at, _now).toLowerCase()}, ${hm(at)}.', undoLocal: () => widget.repo.moveReminder(r.id, before));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return YouPage(
      title: 'Reminders',
      sub: 'What you asked to be reminded of.',
      loading: items == null && _error == null,
      error: items == null ? _error : null,
      onRetry: _load,
      onRefresh: _load,
      children: (themed, c) {
        // Grouped by day, in order.
        final groups = <String, List<Reminder>>{};
        for (final r in items!) {
          groups.putIfAbsent(dayHeading(r.remindAt, _now), () => []).add(r);
        }
        return [
          if (widget.onCheckDelivery != null)
            AllyCard(
              child: Row(children: [
                Expanded(child: Text('Some phones stop reminders to save battery. Check yours in two steps.', style: AllyType.body(color: c.ink))),
                const SizedBox(width: Sp.x2),
                AllyButton('Check', kind: AllyButtonKind.secondary, onPressed: widget.onCheckDelivery),
              ]),
            ),
          if (items.isEmpty)
            Text('Nothing coming up. Say "remind me…" in Talk to add one.', style: AllyType.body(color: c.muted))
          else
            for (final e in groups.entries)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(e.key.toUpperCase(), style: AllyType.eyebrow(color: c.faint)),
                const SizedBox(height: Sp.x2),
                youRows(c, [
                  for (final r in e.value)
                    Pressable(
                      scale: 0.985,
                      onTap: () => _open(themed, r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                        child: Row(children: [
                          SizedBox(width: 56, child: Text(hm(r.remindAt), style: AllyType.num(color: c.muted))),
                          Expanded(child: Text(r.text, style: AllyType.body(color: c.ink))),
                          if (r.repeats) Icon(Icons.repeat_rounded, size: 18, color: c.faint, semanticLabel: 'Repeats'),
                        ]),
                      ),
                    ),
                ]),
              ]),
        ];
      },
    );
  }
}
