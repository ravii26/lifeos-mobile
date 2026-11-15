import 'package:flutter/material.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../data/models/habit.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart' show placesRefresh;
import 'routine_reminders.dart';
import 'routine_when_sheet.dart';
import 'routine_words.dart';

/// One routine: today, the last four weeks, when it happens, its smaller
/// version and its reminder. Every change offers Undo. Counts, not streaks.
class RoutinePage extends StatefulWidget {
  final String habitId;
  final LifeRepository repo;
  final String? areaName;
  final Color? color;

  const RoutinePage({super.key, required this.habitId, required this.repo, this.areaName, this.color});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  Habit? _h;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.repo.habits();
      final h = all.where((x) => x.id == widget.habitId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _h = h;
        _error = h == null ? 'This routine is no longer here.' : null;
      });
    } on ApiException catch (e) {
      if (mounted && _h == null) setState(() => _error = e.message);
    }
  }

  void _toast(BuildContext themed, String text, {Future<void> Function()? undo}) => showAllyToast(themed, text,
      onUndo: undo == null
          ? null
          : () async {
              try {
                await undo();
                placesRefresh.value++;
                await syncRoutineReminders(widget.repo);
                await _load();
              } on ApiException catch (e) {
                if (themed.mounted) showAllyToast(themed, e.message);
              }
            });

  /// Saves one change, then offers to put the old values back.
  Future<void> _change(BuildContext themed, String done, Future<void> Function() apply, Future<void> Function() revert) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await apply();
      placesRefresh.value++;
      await syncRoutineReminders(widget.repo);
      await _load();
      if (themed.mounted) _toast(themed, done, undo: revert);
    } on QueuedOfflineException {
      if (themed.mounted) showAllyToast(themed, "Saved offline. It'll sync when you're back online.");
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleToday(BuildContext themed, Habit h) => _change(
        themed,
        h.todayDone ? 'Marked as not done today.' : 'Done for today.',
        () => widget.repo.logHabit(h.id, completed: !h.todayDone),
        () => widget.repo.logHabit(h.id, completed: h.todayDone),
      );

  Future<void> _editWhen(BuildContext themed, Habit h) async {
    final before = RoutineWhen(frequency: h.frequency, days: h.specificDays, timesAWeek: h.weeklyTarget ?? 3, part: h.timeBlock);
    final v = await showAllySheet<RoutineWhen>(themed, builder: (_) => RoutineWhenSheet(initial: before));
    if (v == null || !themed.mounted) return;
    Future<void> set(RoutineWhen w) => widget.repo.updateHabit(h.id,
        frequency: w.frequency,
        specificDays: w.frequency == 'CUSTOM' ? w.days : const [],
        weeklyTarget: w.frequency == 'WEEKLY' ? w.timesAWeek : null,
        timeBlock: w.part,
        anytime: w.part == null);
    await _change(themed, 'Now: ${v.words}.', () => set(v), () => set(before));
  }

  Future<void> _editSmaller(BuildContext themed, Habit h) async {
    final ctl = TextEditingController(text: h.minimumVersion ?? '');
    final v = await showAllySheet<String>(
      themed,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Smaller version', style: AllyType.h2(color: ctx.ac.ink)),
        const SizedBox(height: Sp.x1),
        Text('What still counts on a hard day.', style: AllyType.body(color: ctx.ac.muted)),
        const SizedBox(height: Sp.x3),
        TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          style: AllyType.body(color: ctx.ac.ink),
          decoration: const InputDecoration(hintText: 'For example: one page', counterText: ''),
        ),
        const SizedBox(height: Sp.x3),
        AllyButton('Save', wide: true, onPressed: () => Navigator.of(ctx).pop(ctl.text.trim())),
      ]),
    );
    ctl.dispose();
    if (v == null || v == (h.minimumVersion ?? '') || !themed.mounted) return;
    await _change(themed, v.isEmpty ? 'Smaller version removed.' : 'Smaller version saved.',
        () => widget.repo.updateHabit(h.id, minimumVersion: v), () => widget.repo.updateHabit(h.id, minimumVersion: h.minimumVersion ?? ''));
  }

  Future<void> _editReminder(BuildContext themed, Habit h, {bool remove = false}) async {
    String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    String? next;
    if (!remove) {
      final parts = (h.reminderTime ?? '08:00').split(':');
      final t = await showTimePicker(
        context: themed,
        initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
      );
      if (t == null || !themed.mounted) return;
      next = hhmm(t);
    }
    await _change(themed, next == null ? 'Reminder removed.' : 'Reminder set for $next.',
        () => widget.repo.updateHabit(h.id, reminderTime: next ?? ''), () => widget.repo.updateHabit(h.id, reminderTime: h.reminderTime ?? ''));
  }

  Future<void> _stop(BuildContext themed, Habit h) async {
    await _change(themed, '${h.title} is stopped. Nothing is deleted.', () => widget.repo.updateHabit(h.id, isActive: false),
        () => widget.repo.updateHabit(h.id, isActive: true));
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyTheme.dark(), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final h = _h;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(),
      body: h == null
          ? Padding(
              padding: const EdgeInsets.all(Sp.side),
              child: _error == null
                  ? const Column(children: [AllySkeleton(height: 34, width: 200), SizedBox(height: Sp.x4), AllySkeleton(height: 160, radius: Rad.card)])
                  : AllyNote(_error!, actionLabel: 'Try again', onAction: _load),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x6), children: [Stagger(children: _content(themed, c, h))]),
    );
  }

  List<Widget> _content(BuildContext themed, AllyColors c, Habit h) {
    final color = widget.color ?? c.ink;
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.areaName != null) AreaLabel(widget.areaName!, color: color),
        const SizedBox(height: Sp.x1),
        Text(h.title, style: AllyType.h1(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text(habitWhen(h), style: AllyType.body(color: c.muted)),
        if (h.stage == 'AUTOMATIC') ...[
          const SizedBox(height: Sp.x1),
          Text('Part of your days now. Ally stops reminding you.', style: AllyType.small(color: c.faint)),
        ],
        if (!h.isActive) ...[
          const SizedBox(height: Sp.x2),
          const AllyBanner('Stopped. Nothing is deleted; start it again any time.', icon: Icons.pause_circle_outline_rounded),
        ],
      ]),
      AllyCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TODAY', style: AllyType.eyebrow(color: c.faint)),
              const SizedBox(height: Sp.x1),
              Text(h.todayDone ? 'Done' : 'Not yet', style: AllyType.h2(color: c.ink)),
            ]),
          ),
          AllyCheck(done: h.todayDone, semanticLabel: '${h.title} today', onTap: _busy || !h.isActive ? null : () => _toggleToday(themed, h)),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, spacing: Sp.x2, runSpacing: Sp.x1, children: [
          Text('LAST 4 WEEKS', style: AllyType.eyebrow(color: c.faint)),
          Text(lastDaysWords(h.history), style: AllyType.small(color: c.faint)),
        ]),
        const SizedBox(height: Sp.x2),
        Semantics(
          container: true,
          label: lastDaysWords(h.history),
          excludeSemantics: true,
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final done in h.history)
                Container(
                  decoration: BoxDecoration(
                    color: done ? color : c.raised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: done ? color : c.line),
                  ),
                ),
            ],
          ),
        ),
      ]),
      _setting(c, 'WHEN', habitWhen(h), 'Change', _busy ? null : () => _editWhen(themed, h)),
      _setting(c, 'SMALLER VERSION', h.minimumVersion?.isNotEmpty == true ? h.minimumVersion! : 'None yet. A smaller version keeps it going on hard days.',
          h.minimumVersion?.isNotEmpty == true ? 'Change' : 'Add', _busy ? null : () => _editSmaller(themed, h)),
      _setting(c, 'REMINDER', h.reminderTime ?? 'No reminder', h.reminderTime == null ? 'Set a time' : 'Change',
          _busy ? null : () => _editReminder(themed, h),
          extra: h.reminderTime == null ? null : AllyButton('Remove', kind: AllyButtonKind.ghost, onPressed: _busy ? null : () => _editReminder(themed, h, remove: true))),
      if (h.isActive)
        AllyButton('Stop this routine', kind: AllyButtonKind.ghost, wide: true, onPressed: _busy ? null : () => _stop(themed, h))
      else
        AllyButton('Start it again', kind: AllyButtonKind.secondary, wide: true,
            onPressed: _busy ? null : () => _change(themed, '${h.title} is back.', () => widget.repo.updateHabit(h.id, isActive: true), () => widget.repo.updateHabit(h.id, isActive: false))),
    ];
  }

  Widget _setting(AllyColors c, String title, String value, String action, VoidCallback? onTap, {Widget? extra}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text(value, style: AllyType.body(color: c.ink)),
          const SizedBox(height: Sp.x1),
          Wrap(spacing: Sp.x2, children: [
            AllyButton(action, kind: AllyButtonKind.secondary, onPressed: onTap),
            ?extra,
          ]),
        ],
      );
}
