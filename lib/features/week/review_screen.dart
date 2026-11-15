import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../areas/areas_overview.dart';
import '../places/now_cubit.dart' show placesRefresh;
import 'review_rules.dart';

/// The weekly review, about ten minutes: what moved, how each Push plan felt,
/// time for next week, and what next weekend's free block is for. Nothing is
/// saved until "Set next week", and that whole set can be undone.
class ReviewScreen extends StatefulWidget {
  final LifeRepository repo;
  const ReviewScreen({super.key, required this.repo});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _pick = '__pick__';

  AreasOverview? _o;
  String? _error;
  int _step = 0;
  bool _busy = false;
  final Map<String, PlanFeel> _feel = {};
  final Map<String, int> _minutes = {};

  /// The Explore area whose next step goes to the weekend, or [_pick].
  String _weekend = _pick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final o = await loadAreasOverview(widget.repo);
      if (!mounted) return;
      setState(() {
        _o = o;
        for (final a in _active) {
          _minutes[a.id] = startingMinutes(a);
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  List<AreaStanding> get _active => (_o?.areas ?? const []).where((a) => a.mode != AreaMode.rest).toList();
  List<AreaStanding> get _push => _active.where((a) => a.mode == AreaMode.push).toList();
  List<AreaStanding> get _explore => _active.where((a) => a.mode == AreaMode.explore && a.nextSteps.isNotEmpty).toList();

  int _colorIndex(String id) => (_o?.areas ?? const []).indexWhere((a) => a.id == id);

  void _setFeel(AreaStanding a, PlanFeel f) => setState(() {
        _feel[a.id] = f;
        _minutes[a.id] = adjusted(startingMinutes(a), f);
      });

  void _nudge(String id, int by) => setState(() => _minutes[id] = ((_minutes[id] ?? 0) + by).clamp(0, reviewMax));

  Future<void> _finish(BuildContext themed) async {
    final o = _o!;
    setState(() => _busy = true);
    final changes = o.full ? timeChanges(_active, _minutes) : const <({String areaId, int? before, int after})>[];
    final done = <({String areaId, int? before, int after})>[];
    String? moveUndo;
    try {
      for (final ch in changes) {
        await widget.repo.updateArea(ch.areaId, weeklyMinutes: ch.after);
        done.add(ch);
      }
      if (_weekend != _pick) {
        final area = _explore.where((a) => a.id == _weekend).firstOrNull;
        final step = area?.nextSteps.firstOrNull;
        if (step != null) moveUndo = (await widget.repo.moveStep(step.id, 'WEEKEND')).activityId;
      }
    } on ApiException catch (e) {
      // Put back what was already saved, so it is all or nothing.
      await _undo(done, null);
      if (mounted) setState(() => _busy = false);
      if (themed.mounted) showAllyToast(themed, e.message);
      return;
    }
    placesRefresh.value++;
    if (!mounted || !themed.mounted) return;
    final nothing = done.isEmpty && moveUndo == null;
    showAllyToast(themed, nothing ? 'Next week stays as it is.' : 'Next week is set.', onUndo: nothing ? null : () => _undo(done, moveUndo));
    Navigator.of(context).pop(true);
  }

  Future<void> _undo(List<({String areaId, int? before, int after})> done, String? moveUndo) async {
    try {
      for (final ch in done) {
        await widget.repo.updateArea(ch.areaId, weeklyMinutes: ch.before, clearWeeklyMinutes: ch.before == null);
      }
      if (moveUndo != null) await widget.repo.undo(moveUndo);
      placesRefresh.value++;
    } on ApiException catch (_) {
      // The screen may have closed; the next load shows what is saved.
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final o = _o;
    final ready = o != null && _active.isNotEmpty;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        actions: [
          if (ready)
            Padding(
              padding: const EdgeInsets.only(right: Sp.side),
              child: Center(child: Text('${_step + 1} / 4', style: AllyType.num(color: c.faint))),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (ready) _bar(c),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x4, Sp.side, Sp.x4),
              children: [
                if (o == null && _error == null)
                  const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    AllySkeleton(height: 34, width: 180),
                    SizedBox(height: Sp.x4),
                    AllySkeleton(height: 220, radius: Rad.card),
                  ])
                else if (o == null)
                  _problem(c, "Couldn't load your areas", _error ?? '')
                else if (_active.isEmpty)
                  _problem(c, 'Nothing to review yet', 'Add an area, or bring one back from Rest, and the review has something to look at.', retry: false)
                else
                  Stagger(key: ValueKey(_step), gap: Sp.x4, children: _content(c, o)),
              ],
            ),
          ),
          if (ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x2, Sp.side, Sp.x4),
              child: AllyButton(
                _step < 3 ? 'Next' : 'Set next week',
                wide: true,
                onPressed: _busy ? null : (_step < 3 ? () => setState(() => _step++) : () => _finish(themed)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _bar(AllyColors c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.side),
        child: Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: Sp.x1),
            Expanded(
              child: AnimatedContainer(
                duration: Motion.reduced(context) ? Duration.zero : Motion.d2,
                height: 4,
                decoration: BoxDecoration(color: i <= _step ? c.ink : c.raised, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ]),
      );

  Widget _problem(AllyColors c, String title, String body, {bool retry = true}) => AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AllyType.h2(color: c.ink)),
          const SizedBox(height: Sp.x1),
          Text(body, style: AllyType.body(color: c.muted)),
          if (retry) ...[const SizedBox(height: Sp.x4), AllyButton('Try again', onPressed: _load)],
        ]),
      );

  List<Widget> _content(AllyColors c, AreasOverview o) => switch (_step) {
        0 => _moved(c),
        1 => _plans(c),
        2 => _time(c, o),
        _ => _weekendStep(c),
      };

  List<Widget> _moved(AllyColors c) => [
        Text('What moved', style: AllyType.h1(color: c.ink)),
        AllyCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
          child: Column(children: [
            for (var k = 0; k < _active.length; k++) ...[
              if (k > 0) Divider(color: c.line, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Row(children: [
                  ProgressRing(value: _active[k].value, color: c.area(_colorIndex(_active[k].id)), size: 36, stroke: 5),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_active[k].name, style: AllyType.body(color: c.ink)),
                      Text(
                        '${_active[k].minutes > 0 ? minutesLabel(_active[k].minutes) : 'Nothing'} · ${_active[k].status}',
                        style: AllyType.small(color: c.faint),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        Text('Counts, not grades. A quiet area is information, not failure.', style: AllyType.small(color: c.faint)),
      ];

  List<Widget> _plans(AllyColors c) => [
        Text('Plans for next week', style: AllyType.h1(color: c.ink)),
        if (_push.isEmpty)
          Text('No Push areas right now, so nothing to tune here. Next.', style: AllyType.body(color: c.muted))
        else
          for (final a in _push)
            AllyCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AreaLabel(a.name, color: c.area(_colorIndex(a.id))),
                if (a.nextSteps.isNotEmpty) ...[
                  const SizedBox(height: Sp.x2),
                  Text('Next: ${a.nextSteps.take(3).map((s) => s.title).join(' · ')}', style: AllyType.body(color: c.muted)),
                ],
                const SizedBox(height: Sp.x3),
                Text('HOW DID THIS WEEK FEEL?', style: AllyType.eyebrow(color: c.faint)),
                const SizedBox(height: Sp.x2),
                AllySegmented<PlanFeel>(
                  options: {for (final f in PlanFeel.values) f: f.label},
                  value: _feel[a.id] ?? PlanFeel.same,
                  onChanged: (f) => _setFeel(a, f),
                ),
              ]),
            ),
      ];

  List<Widget> _time(AllyColors c, AreasOverview o) {
    final total = _active.fold<int>(0, (s, a) => s + (_minutes[a.id] ?? 0));
    final note = overNote(total, o.freeMinutes);
    return [
      Text('Time for next week', style: AllyType.h1(color: c.ink)),
      if (!o.full)
        const AllyNote('Setting weekly time needs the latest server. Your weekend choice still saves.')
      else
        Text(
          o.freeMinutes > 0 ? 'Free: about ${minutesLabel(o.freeMinutes)}. Planned: ${minutesLabel(total)}.' : 'Planned: ${minutesLabel(total)}.',
          style: AllyType.body(color: c.muted),
        ),
      if (o.full)
        AllyCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
          child: Column(children: [
            for (var k = 0; k < _active.length; k++) ...[
              if (k > 0) Divider(color: c.line, height: 1),
              _stepperRow(c, _active[k]),
            ],
          ]),
        ),
      if (note != null) AllyNote(note),
    ];
  }

  Widget _stepperRow(AllyColors c, AreaStanding a) {
    final m = _minutes[a.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Sp.x2,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            AreaLabel(a.name, color: c.area(_colorIndex(a.id))),
            Text(a.mode.label, style: AllyType.small(color: c.faint)),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Less for ${a.name}',
              icon: const Icon(Icons.remove_rounded),
              onPressed: m <= 0 ? null : () => _nudge(a.id, -reviewStep),
            ),
            SizedBox(
              width: 64,
              child: Text(minutesLabel(m), textAlign: TextAlign.center, style: AllyType.num(color: c.ink)),
            ),
            IconButton(
              tooltip: 'More for ${a.name}',
              icon: const Icon(Icons.add_rounded),
              onPressed: m >= reviewMax ? null : () => _nudge(a.id, reviewStep),
            ),
          ]),
        ],
      ),
    );
  }

  List<Widget> _weekendStep(AllyColors c) => [
        Text('Next weekend', style: AllyType.h1(color: c.ink)),
        Text(
          _explore.isEmpty
              ? 'No Explore areas with a next step, so the weekend block stays open. Ally picks on the day.'
              : 'Free weekend time goes to your Explore areas. What should the weekend block be?',
          style: AllyType.body(color: c.muted),
        ),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final a in _explore) AllyChip(a.name, selected: _weekend == a.id, onTap: () => setState(() => _weekend = a.id)),
          AllyChip('Let Ally pick on the day', selected: _weekend == _pick, onTap: () => setState(() => _weekend = _pick)),
        ]),
        if (_weekend != _pick)
          Text(
            'Moves "${_explore.firstWhere((a) => a.id == _weekend).nextSteps.first.title}" to the weekend.',
            style: AllyType.small(color: c.faint),
          ),
      ];
}
