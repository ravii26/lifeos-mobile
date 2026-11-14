import 'package:flutter/material.dart';

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
    final a = widget.area;
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
            _section(c, 'Mode', [
              AllySegmented<AreaMode>(
                options: {for (final m in AreaMode.values) m: m.label},
                value: _mode,
                onChanged: (m) => _setMode(themed, m),
              ),
              const SizedBox(height: Sp.x2),
              Text(_mode.meaning, style: AllyType.small(color: c.muted)),
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
            ]),
            _section(c, 'Next steps', [
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
                AllyButton(
                  a.goals.isEmpty ? 'Tell Ally what you want here' : 'Ask Ally for the next step',
                  kind: AllyButtonKind.secondary,
                  wide: true,
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    talkRequest.value++;
                  },
                ),
              ],
            ]),
            if (a.routines.isNotEmpty)
              _section(c, 'Routines', [
                for (final r in a.routines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x2),
                    child: Row(children: [
                      Expanded(child: Text(r.title, style: AllyType.body(color: c.ink))),
                      Text('${r.doneThisWeek}× this week', style: AllyType.num(color: c.faint)),
                    ]),
                  ),
              ]),
          ]),
        ],
      ),
    );
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x2),
            child: Text(
              s.title,
              style: AllyType.body(color: s.done ? c.faint : c.ink, w: FontWeight.w500)
                  .copyWith(decoration: s.done ? TextDecoration.lineThrough : null),
            ),
          ),
        ),
        if (s.minutes != null && s.minutes! > 0) Text(duration(s.minutes!), style: AllyType.num(color: c.faint)),
        AllyCheck(done: s.done, semanticLabel: s.title, onTap: s.done ? null : () => _tick(themed, s)),
      ]);
}
