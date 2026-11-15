import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../chat/starters.dart' show talkRequest;
import '../places/now_cubit.dart' show placesRefresh;
import '../today/day_shape.dart' show duration;
import 'areas_overview.dart';
import '../places/done_screen.dart' show DoneChoice;
import '../session/completion_screen.dart';
import '../session/focus_session_screen.dart';
import 'concrete_goal_screen.dart';
import '../../design/trend_line.dart';
import 'number_sheets.dart';
import 'plan_mode_sheet.dart';
import 'step_sheet.dart';
import '../routines/new_routine_screen.dart';
import '../routines/routine_page.dart';
import 'tastes_sheet.dart';

/// One area: where it stands this week, its mode, the time it gets, and what
/// is next in it.
class AreaPage extends StatefulWidget {
  final AreaStanding area;

  /// Its position in the person's list, which decides its colour.
  final int colorIndex;

  /// False on a server that cannot store weekly time yet.
  final bool canSetTime;
  final LifeRepository repo;

  const AreaPage({super.key, required this.area, required this.colorIndex, required this.canSetTime, required this.repo});

  @override
  State<AreaPage> createState() => _AreaPageState();
}

class _AreaPageState extends State<AreaPage> {
  // Refreshed after a step changes, so the page always shows what is true.
  late AreaStanding _area = widget.area;
  late AreaMode _mode = widget.area.mode;
  late int? _weekly = widget.area.weeklyMinutes;
  bool _saving = false;

  // Weekly time moves in half hours, up to 40 hours.
  static const _step = 30;
  static const _max = 2400;

  Future<void> _setMode(BuildContext themed, AreaMode next) async {
    if (next == _mode || _saving) return;
    final before = _mode;
    setState(() {
      _mode = next;
      _saving = true;
    });
    try {
      await widget.repo.updateArea(widget.area.id, tier: next.tier);
      placesRefresh.value++;
      if (themed.mounted) {
        showAllyToast(themed, '${widget.area.name} is now ${next.label}.', onUndo: () => _setMode(themed, before));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _mode = before);
      if (themed.mounted) showAllyToast(themed, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setWeekly(BuildContext themed, int? next) async {
    if (_saving) return;
    final before = _weekly;
    setState(() {
      _weekly = next;
      _saving = true;
    });
    try {
      await widget.repo.updateArea(widget.area.id, weeklyMinutes: next, clearWeeklyMinutes: next == null);
      placesRefresh.value++;
    } on ApiException catch (e) {
      if (mounted) setState(() => _weekly = before);
      if (themed.mounted) showAllyToast(themed, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tick(BuildContext themed, AreaStep step) async {
    if (step.done) return;
    setState(() => step.done = true);
    try {
      final id = await widget.repo.respondNow('TASK', step.id, 'DONE');
      placesRefresh.value++;
      if (!themed.mounted) return;
      showAllyToast(
        themed,
        'Done',
        onUndo: id == null
            ? null
            : () async {
                try {
                  await widget.repo.undo(id);
                  placesRefresh.value++;
                  if (mounted) setState(() => step.done = false);
                } on ApiException catch (e) {
                  if (themed.mounted) showAllyToast(themed, e.message);
                }
              },
      );
    } on QueuedOfflineException {
      if (themed.mounted) showAllyToast(themed, "Saved offline. It'll sync when you're back online.");
    } on ApiException catch (e) {
      if (mounted) setState(() => step.done = false);
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: AllyTheme.dark(), child: Builder(builder: _page));
  }

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final a = _area;
    final color = c.area(widget.colorIndex);
    final resting = _mode == AreaMode.rest;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x6),
        children: [
          Stagger(children: [
            Row(children: [
              ProgressRing(
                value: resting ? 0 : a.value,
                color: color,
                size: 76,
                stroke: 8,
                semanticLabel: 'This week',
                child: Text('${(a.value * 100).round()}%', style: AllyType.num(color: c.ink)),
              ),
              const SizedBox(width: Sp.x4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, style: AllyType.h1(color: c.ink)),
                  const SizedBox(height: Sp.x1),
                  Text(a.status, style: AllyType.body(color: c.muted)),
                ]),
              ),
            ]),
            if (a.tastes != null || (_mode == AreaMode.explore && a.goals.isEmpty)) _tastesCard(themed, c, a),
            _section(c, 'Mode', [
              AllySegmented<AreaMode>(
                options: {for (final m in AreaMode.values) m: m.label},
                value: _mode,
                onChanged: (m) => _setMode(themed, m),
              ),
              const SizedBox(height: Sp.x2),
              Text(_mode.meaning, style: AllyType.small(color: c.muted)),
              const SizedBox(height: Sp.x2),
              if (a.planned != null)
                Row(children: [
                  Icon(Icons.event_outlined, size: 18, color: c.muted),
                  const SizedBox(width: Sp.x2),
                  Expanded(
                    child: Text('Becomes ${a.planned!.mode.label} on ${shortDay(a.planned!.on)}', style: AllyType.body(color: c.ink)),
                  ),
                  AllyButton('Cancel', kind: AllyButtonKind.ghost, onPressed: _saving ? null : () => _cancelPlanned(themed)),
                ])
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: AllyButton('Plan a change for later',
                      kind: AllyButtonKind.ghost, icon: Icons.event_outlined, onPressed: _saving ? null : () => _planChange(themed)),
                ),
            ]),
            if (widget.canSetTime && !resting)
              _section(c, 'Time each week', [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_weekly == null ? 'Not set' : duration(_weekly!), style: AllyType.h2(color: c.ink)),
                      Text(
                        _weekly == null
                            ? (a.plannedMinutes > 0 ? "Using your goals' targets: ${duration(a.plannedMinutes)}." : 'Ally counts days with something done.')
                            : 'Compared with your free time as a suggestion, never a limit.',
                        style: AllyType.small(color: c.faint),
                      ),
                    ]),
                  ),
                  _round(c, Icons.remove_rounded, 'Less time', _weekly == null ? null : () => _setWeekly(themed, _weekly! - _step <= 0 ? null : _weekly! - _step)),
                  const SizedBox(width: Sp.x2),
                  _round(c, Icons.add_rounded, 'More time',
                      (_weekly ?? 0) >= _max ? null : () => _setWeekly(themed, (_weekly ?? (a.plannedMinutes > 0 ? a.plannedMinutes ~/ _step * _step : 0)) + _step)),
                ]),
              ]),
            _section(c, 'Goal', [
              if (a.goals.isEmpty)
                Text('No goal here yet.', style: AllyType.body(color: c.muted))
              else
                for (final g in a.goals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x1),
                    child: Text(g, style: AllyType.body(color: c.ink, w: FontWeight.w500)),
                  ),
              if (!resting) ...[
                const SizedBox(height: Sp.x3),
                AllyButton(a.goals.isEmpty ? 'Make a goal concrete' : 'Add a goal, made concrete',
                    kind: a.goals.isEmpty ? AllyButtonKind.main : AllyButtonKind.secondary,
                    icon: Icons.flag_outlined,
                    wide: true,
                    onPressed: () => _concrete(themed)),
              ],
            ]),
            _section(c, 'Next steps', [
              if (a.reworking && a.nextSteps.isNotEmpty && !_reworkHidden) ...[
                _reworkCard(themed, c, a),
                const SizedBox(height: Sp.x3),
              ],
              if (a.nextSteps.isEmpty)
                Text(resting ? 'Resting. Nothing is asked here.' : 'Nothing lined up.', style: AllyType.body(color: c.muted))
              else
                AllyCard(
                  padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x1, Sp.x1, Sp.x1),
                  child: Column(children: [
                    for (var i = 0; i < a.nextSteps.length; i++) ...[
                      if (i > 0) Divider(color: c.line, height: 1),
                      _stepRow(themed, c, a.nextSteps[i]),
                    ],
                  ]),
                ),
              if (!resting) ...[
                const SizedBox(height: Sp.x3),
                AllyButton('Add a step',
                    kind: AllyButtonKind.secondary, icon: Icons.add_rounded, wide: true, onPressed: () => _openStep(themed, null)),
                const SizedBox(height: Sp.x2),
                AllyButton(
                  a.goals.isEmpty ? 'Tell Ally what you want here' : 'Ask Ally for the next step',
                  kind: AllyButtonKind.ghost,
                  wide: true,
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    talkRequest.value++;
                  },
                ),
              ],
            ]),
            if (a.numbers.isNotEmpty || !resting)
              _section(c, a.numbers.length > 1 ? 'Tracked numbers' : 'Tracked number', [
                for (final n in a.numbers) ...[
                  _numberCard(themed, c, n, color),
                  const SizedBox(height: Sp.x2),
                ],
                if (!resting)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AllyButton(a.numbers.isEmpty ? 'Track a number' : 'Track another number',
                        kind: AllyButtonKind.ghost, icon: Icons.show_chart_rounded, onPressed: () => _trackNumber(themed)),
                  ),
              ]),
            if (a.routines.isNotEmpty || !resting)
              _section(c, 'Routines', [
                for (final r in a.routines)
                  Pressable(
                    scale: 0.985,
                    onTap: () => _openRoutine(themed, r.id, color),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                      child: Row(children: [
                        Expanded(child: Text(r.title, style: AllyType.body(color: c.ink))),
                        Text('${r.doneThisWeek}× this week', style: AllyType.num(color: c.faint)),
                        Icon(Icons.chevron_right_rounded, color: c.faint),
                      ]),
                    ),
                  ),
                if (!resting)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AllyButton('Add a routine', kind: AllyButtonKind.ghost, icon: Icons.add_rounded, onPressed: () => _addRoutine(themed)),
                  ),
              ]),
          ]),
        ],
      ),
    );
  }

  Future<void> _reload() async {
    try {
      final all = (await loadAreasOverview(widget.repo)).areas;
      final fresh = all.where((x) => x.id == _area.id);
      if (fresh.isNotEmpty && mounted) {
        setState(() {
          _area = fresh.first;
          _mode = fresh.first.mode;
        });
      }
    } on ApiException {
      // The page keeps what it had; the toast already said what happened.
    }
  }

  // "Try step one first?" is shown at most once a week per area.
  bool _reworkHidden = false;
  String get _reworkKey => 'rework_hidden_${widget.area.id}';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final at = DateTime.tryParse(p.getString(_reworkKey) ?? '');
      if (at != null && DateTime.now().difference(at).inDays < 7 && mounted) setState(() => _reworkHidden = true);
    }).catchError((_) {});
  }

  Future<void> _hideRework() async {
    setState(() => _reworkHidden = true);
    try {
      (await SharedPreferences.getInstance()).setString(_reworkKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// One gentle line, never a block: the steps keep changing and nothing is getting done.
  Widget _reworkCard(BuildContext themed, AllyColors c, AreaStanding a) {
    final first = a.nextSteps.first;
    final minutes = (first.minutes ?? 15).clamp(5, 15);
    return AllyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('These steps have changed a few times. Try the first one as it is?', style: AllyType.body(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('$minutes minutes is enough to learn what to change.', style: AllyType.small(color: c.faint)),
        const SizedBox(height: Sp.x3),
        Row(children: [
          Expanded(child: AllyButton('Try it', wide: true, onPressed: () => _tryFirst(themed, first, minutes))),
          const SizedBox(width: Sp.x2),
          Expanded(child: AllyButton('Not now', kind: AllyButtonKind.ghost, wide: true, onPressed: _hideRework)),
        ]),
      ]),
    );
  }

  Future<void> _tryFirst(BuildContext themed, AreaStep step, int minutes) async {
    final color = themed.ac.area(widget.colorIndex);
    final outcome = await Navigator.of(context).push<FocusOutcome>(MaterialPageRoute(
      builder: (_) => FocusSessionScreen(title: step.title, minutes: minutes, areaName: _area.name, areaColor: color),
    ));
    if (!mounted || !themed.mounted || outcome?.end != FocusEnd.done) return;
    await _tick(themed, step);
  }

  Future<void> _planChange(BuildContext themed) async {
    final picked = await showAllySheet<(AreaMode, DateTime)>(themed, builder: (_) => PlanModeSheet(areaName: _area.name, current: _mode));
    if (picked == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repo.updateArea(_area.id, nextTier: picked.$1.tier, nextTierOn: picked.$2);
      placesRefresh.value++;
      await _reload();
      if (themed.mounted) showAllyToast(themed, 'Planned. You can cancel it here anytime.');
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelPlanned(BuildContext themed) async {
    final was = _area.planned;
    setState(() => _saving = true);
    try {
      await widget.repo.updateArea(_area.id, clearPlanned: true);
      placesRefresh.value++;
      await _reload();
      if (!themed.mounted) return;
      showAllyToast(
        themed,
        'Planned change cancelled.',
        onUndo: was == null
            ? null
            : () async {
                try {
                  await widget.repo.updateArea(_area.id, nextTier: was.mode.tier, nextTierOn: DateTime.parse(was.on));
                  placesRefresh.value++;
                  await _reload();
                } on ApiException catch (e) {
                  if (themed.mounted) showAllyToast(themed, e.message);
                }
              },
      );
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openRoutine(BuildContext themed, String id, Color color) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RoutinePage(habitId: id, repo: widget.repo, areaName: _area.name, color: color),
    ));
    await _reload();
  }

  Future<void> _addRoutine(BuildContext themed) async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => NewRoutineScreen(repo: widget.repo, areas: [(_area.id, _area.name)], areaId: _area.id),
    ));
    if (added != true || !mounted) return;
    placesRefresh.value++;
    await _reload();
    if (themed.mounted) showAllyToast(themed, 'Routine added to ${_area.name}.');
  }

  Widget _numberCard(BuildContext themed, AllyColors c, TrackedNumber n, Color color) => AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(n.name, style: AllyType.body(color: c.ink, w: FontWeight.w600))),
            Text('${n.percent}%', style: AllyType.num(color: c.faint)),
          ]),
          const SizedBox(height: Sp.x1),
          Text(n.line, style: AllyType.small(color: c.muted)),
          const SizedBox(height: Sp.x3),
          TrendLine(
            points: n.points,
            target: n.target,
            color: color,
            semanticLabel: '${n.name}: ${n.line}. ${n.trendWords}.',
          ),
          const SizedBox(height: Sp.x2),
          Text(n.trendWords, style: AllyType.small(color: c.faint)),
          const SizedBox(height: Sp.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: AllyButton('Add a reading', kind: AllyButtonKind.secondary, icon: Icons.add_rounded, onPressed: () => _addReading(themed, n)),
          ),
        ]),
      );

  Future<void> _trackNumber(BuildContext themed) async {
    final d = await showAllySheet<NewNumberDraft>(themed, builder: (_) => TrackNumberSheet(areaName: _area.name));
    if (d == null || !mounted) return;
    try {
      final r = await widget.repo.trackNumber(_area.id, name: d.name, unit: d.unit, start: d.start, target: d.target);
      placesRefresh.value++;
      await _reload();
      if (!themed.mounted) return;
      final undoId = r.activityId;
      showAllyToast(themed, r.message, onUndo: undoId == null ? null : () => _undo(themed, undoId));
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.isNotFound ? 'Tracking numbers needs the latest server. Deploy it, then try again.' : e.message);
    }
  }

  Future<void> _addReading(BuildContext themed, TrackedNumber n) async {
    final v = await showAllySheet<double>(themed, builder: (_) => ReadingSheet(number: n));
    if (v == null || !mounted) return;
    try {
      final r = await widget.repo.logReading(n.projectId, v);
      placesRefresh.value++;
      await _reload();
      if (!themed.mounted) return;
      final undoId = r.activityId;
      showAllyToast(themed, r.message, onUndo: undoId == null ? null : () => _undo(themed, undoId));
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  /// An unsure area: plan three tastes, show where they stand, then decide.
  Widget _tastesCard(BuildContext themed, AllyColors c, AreaStanding a) {
    final t = a.tastes;
    if (t == null) {
      return AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('NOT SURE YET?', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text('Try three small tastes of ${a.name}, then decide. Clarity comes from trying.', style: AllyType.body(color: c.ink)),
          const SizedBox(height: Sp.x3),
          AllyButton('Plan three tastes', kind: AllyButtonKind.secondary, wide: true, onPressed: () => _planTastes(themed)),
        ]),
      );
    }
    if (!t.decide) {
      return AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TASTE ${(t.done + 1).clamp(1, t.total)} OF ${t.total}', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text('Not sure yet is fine. Each taste comes up in your free time; then you decide.', style: AllyType.body(color: c.ink)),
        ]),
      );
    }
    return AllyCard(
      strong: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${t.done == 1 ? 'ONE TASTE' : '${t.done} TASTES'} DONE', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x1),
        Text('What now for ${a.name}?', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x4),
        AllyButton('Keep going: make it concrete', wide: true, onPressed: _saving ? null : () => _decide(themed, 'KEEP')),
        const SizedBox(height: Sp.x2),
        AllyButton('Try another direction', kind: AllyButtonKind.secondary, wide: true, onPressed: _saving ? null : () => _decide(themed, 'CHANGE')),
        AllyButton('Drop it for now', kind: AllyButtonKind.ghost, wide: true, onPressed: _saving ? null : () => _decide(themed, 'DROP')),
      ]),
    );
  }

  Future<void> _planTastes(BuildContext themed) async {
    final picked = await showAllySheet<List<TasteDraft>>(
      themed,
      builder: (_) => TastesSheet(areaId: _area.id, areaName: _area.name, repo: widget.repo),
    );
    if (picked == null || !mounted || !themed.mounted) return;
    try {
      final r = await widget.repo.startTastes(_area.id, picked);
      placesRefresh.value++;
      await _reload();
      if (!themed.mounted) return;
      final undoId = r.activityId;
      showAllyToast(themed, r.message, onUndo: undoId == null ? null : () => _undo(themed, undoId));
    } on ApiException catch (e) {
      if (themed.mounted) {
        showAllyToast(themed, e.isNotFound ? 'Tastes need the latest server. Deploy it, then try again.' : e.message);
      }
    }
  }

  /// KEEP and CHANGE go straight on to the next thing; DROP rests the area, with Undo.
  Future<void> _decide(BuildContext themed, String decision) async {
    setState(() => _saving = true);
    try {
      final r = await widget.repo.decideTastes(_area.id, decision);
      placesRefresh.value++;
      await _reload();
      if (!mounted || !themed.mounted) return;
      setState(() => _saving = false);
      final undoId = r.activityId;
      showAllyToast(themed, r.message, onUndo: undoId == null ? null : () => _undo(themed, undoId));
      if (decision == 'KEEP') await _concrete(themed);
      if (decision == 'CHANGE' && themed.mounted) await _planTastes(themed);
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  /// "Make a goal concrete": three answers → draft plan → start step one now, or later.
  Future<void> _concrete(BuildContext themed) async {
    final repo = widget.repo;
    final kept = await Navigator.of(context).push<KeptPlan>(MaterialPageRoute(
      builder: (_) => ConcreteGoalScreen(areaId: _area.id, areaName: _area.name, repo: repo),
    ));
    if (kept == null || !mounted) return;
    placesRefresh.value++;
    await _reload();
    if (!mounted || !themed.mounted) return;
    final stepId = kept.stepId;
    if (!kept.startNow || stepId == null) {
      final undoId = kept.activityId;
      showAllyToast(themed, 'Saved to ${_area.name} as draft 1.', onUndo: undoId == null ? null : () => _undo(themed, undoId));
      return;
    }
    final title = kept.stepTitle ?? kept.goalTitle;
    final color = themed.ac.area(widget.colorIndex);
    final outcome = await Navigator.of(context).push<FocusOutcome>(MaterialPageRoute(
      builder: (_) => FocusSessionScreen(title: title, minutes: kept.stepMinutes, areaName: _area.name, areaColor: color),
    ));
    if (!mounted || !themed.mounted || outcome?.end != FocusEnd.done) return;
    try {
      final id = await repo.respondNow('TASK', stepId, 'DONE');
      placesRefresh.value++;
      await _reload();
      if (!mounted) return;
      final choice = await Navigator.of(context).push<DoneChoice>(MaterialPageRoute(
        builder: (_) => CompletionScreen(title: title, minutes: outcome!.minutes, canUndo: id != null),
      ));
      if (choice == DoneChoice.undo && id != null && themed.mounted) await _undo(themed, id);
    } on QueuedOfflineException {
      if (themed.mounted) showAllyToast(themed, "Saved offline. It'll sync when you're back online.");
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  Future<void> _undo(BuildContext themed, String id) async {
    try {
      await widget.repo.undo(id);
      placesRefresh.value++;
      await _reload();
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  /// Add (step null) or change a step: one sheet, then one call, with Undo.
  Future<void> _openStep(BuildContext themed, AreaStep? step) async {
    final answer = await showAllySheet<StepAnswer>(themed, builder: (_) => StepSheet(step: step, areaName: _area.name));
    if (answer == null || !mounted) return;
    final repo = widget.repo;
    try {
      final r = switch (answer) {
        StepSave(:final title, :final minutes, :final energy, :final smaller) => step == null
            ? await repo.addStep(_area.id, title, minutes: minutes, energy: energy, smaller: smaller)
            : await repo.editStep(step.id,
                title: title,
                minutes: minutes,
                clearMinutes: minutes == null && step.minutes != null,
                energy: energy,
                smaller: smaller),
        StepMove(when: final to) => await repo.moveStep(step!.id, to),
        StepLetGo() => await repo.letGoStep(step!.id),
      };
      placesRefresh.value++;
      await _reload();
      if (!themed.mounted) return;
      final undoId = r.activityId;
      showAllyToast(
        themed,
        r.message,
        onUndo: undoId == null
            ? null
            : () async {
                try {
                  await repo.undo(undoId);
                  placesRefresh.value++;
                  await _reload();
                } on ApiException catch (e) {
                  if (themed.mounted) showAllyToast(themed, e.message);
                }
              },
      );
    } on ApiException catch (e) {
      if (!themed.mounted) return;
      // A server from before steps existed answers 404 for all of them.
      showAllyToast(themed, e.isNotFound && step == null ? 'Adding steps needs the latest server. Deploy it, then try again.' : e.message);
    }
  }

  Widget _section(AllyColors c, String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x3),
          ...children,
        ],
      );

  Widget _round(AllyColors c, IconData icon, String label, VoidCallback? onTap) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Pressable(
          onTap: onTap,
          scale: 0.92,
          semanticLabel: label,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Rad.chip), border: Border.all(color: c.line)),
            child: Icon(icon, color: c.ink, size: 22),
          ),
        ),
      );

  Widget _stepRow(BuildContext themed, AllyColors c, AreaStep s) => Row(children: [
        Expanded(
          child: Pressable(
            scale: 0.985,
            onTap: s.done ? null : () => _openStep(themed, s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.x2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  s.title,
                  style: AllyType.body(color: s.done ? c.faint : c.ink, w: FontWeight.w500)
                      .copyWith(decoration: s.done ? TextDecoration.lineThrough : null),
                ),
                if (s.energy == 'HIGH' || s.energy == 'LOW' || (s.smaller != null && s.smaller!.isNotEmpty))
                  Text(
                    [
                      if (s.energy == 'HIGH') 'Demanding',
                      if (s.energy == 'LOW') 'Light',
                      if (s.smaller != null && s.smaller!.isNotEmpty) 'Smaller: ${s.smaller}',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AllyType.small(color: c.faint),
                  ),
              ]),
            ),
          ),
        ),
        if (s.minutes != null && s.minutes! > 0) Text(duration(s.minutes!), style: AllyType.num(color: c.faint)),
        AllyCheck(done: s.done, semanticLabel: s.title, onTap: s.done ? null : () => _tick(themed, s)),
      ]);
}
