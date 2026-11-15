import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart' show placesRefresh;
import '../routines/new_routine_screen.dart';
import '../routines/routine_page.dart';
import 'week_data.dart';

/// Week: seven days as bars (done solid, planned faded), the chosen day's
/// detail, routines as seven dots, time per area, and once a month a look
/// back. Counts, never scores; nothing is called missed.
class WeekScreen extends StatefulWidget {
  /// For tests.
  final LifeRepository? repo;
  const WeekScreen({super.key, this.repo});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late final LifeRepository _repo = widget.repo ?? getIt<LifeRepository>();
  WeekData? _data;
  String? _error;
  bool _needsServer = false;
  int? _day;

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = WeekData.fromJson(await _repo.week());
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
          _needsServer = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted || _data != null) return;
      setState(() {
        _needsServer = e.isNotFound;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AllyTheme.dark(),
    child: Builder(builder: _page),
  );

  Widget _page(BuildContext context) {
    final c = context.ac;
    final d = _data;
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.ink,
          backgroundColor: c.raised,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x4, Sp.side, Sp.x6),
            children: [
              if (d == null && _error == null)
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AllySkeleton(height: 34, width: 180),
                    SizedBox(height: Sp.x5),
                    AllySkeleton(height: 190, radius: Rad.card),
                    SizedBox(height: Sp.x4),
                    AllySkeleton(height: 120, radius: Rad.card),
                  ],
                )
              else if (d == null)
                _problem(c)
              else
                Stagger(children: _content(c, d)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _problem(AllyColors c) => AllyCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_needsServer ? 'Week needs the latest server' : "Couldn't load your week", style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text(_needsServer ? 'Deploy it, then pull down to refresh.' : _error ?? '', style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x4),
        AllyButton('Try again', onPressed: _load),
      ],
    ),
  );

  List<Widget> _content(AllyColors c, WeekData d) {
    final day = _day ?? d.todayIndex;
    final active = d.areas.where((a) => a.mode != 'REST').toList();
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.label.toUpperCase(), style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text('This week', style: AllyType.h1(color: c.ink)),
        ],
      ),
      AllyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Bars(data: d, selected: day, onSelect: (i) => setState(() => _day = i)),
            const SizedBox(height: Sp.x3),
            Text('Solid is done. Faded is planned. Tap a day.', style: AllyType.small(color: c.faint)),
          ],
        ),
      ),
      if (d.days.isNotEmpty) _dayDetail(c, d, day),
      _routines(c, d),
      if (active.isNotEmpty) _timePerArea(c, d, active),
      if (d.lookBack != null) _lookBack(c, d.lookBack!),
    ];
  }

  Widget _dayDetail(AllyColors c, WeekData d, int i) {
    final day = d.days[i];
    final rows = <Widget>[
      for (final x in day.done) _areaRow(c, d, x.areaId, hoursLabel(x.minutes), faded: false),
      for (final x in day.planned) _areaRow(c, d, x.areaId, '${hoursLabel(x.minutes)} planned', faded: true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${day.label.toUpperCase()}${day.key == d.todayKey ? ' · TODAY' : ''}', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        if (rows.isEmpty)
          Text(
            day.key.compareTo(d.todayKey) > 0 ? 'Nothing planned yet. Free time stays free.' : 'Nothing logged on this day.',
            style: AllyType.body(color: c.muted),
          )
        else
          AllyCard(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
            child: Column(
              children: [
                for (var k = 0; k < rows.length; k++) ...[if (k > 0) Divider(color: c.line, height: 1), rows[k]],
              ],
            ),
          ),
      ],
    );
  }

  Widget _areaRow(AllyColors c, WeekData d, String areaId, String right, {required bool faded}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Sp.x3),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: Sp.x2,
      runSpacing: Sp.x1,
      children: [
        AreaLabel(d.nameOf(areaId), color: c.area(d.colorIndexOf(areaId)).withValues(alpha: faded ? 0.45 : 1)),
        Text(right, style: AllyType.num(color: faded ? c.faint : c.muted)),
      ],
    ),
  );

  Future<void> _openRoutine(WeekData d, WeekRoutine r) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RoutinePage(habitId: r.id, repo: _repo, areaName: d.nameOf(r.areaId), color: AllyColors.dark.area(d.colorIndexOf(r.areaId))),
      ),
    );
    await _load();
  }

  Future<void> _newRoutine(WeekData d) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewRoutineScreen(
          repo: _repo,
          areas: [
            for (final a in d.areas)
              if (a.mode != 'REST') (a.id, a.name),
          ],
        ),
      ),
    );
    if (added == true) {
      placesRefresh.value++;
      await _load();
    }
  }

  Widget _routines(AllyColors c, WeekData d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text('ROUTINES · THIS WEEK', style: AllyType.eyebrow(color: c.faint)),
          ),
          AllyButton('Routine', kind: AllyButtonKind.ghost, icon: Icons.add_rounded, onPressed: () => _newRoutine(d)),
        ],
      ),
      const SizedBox(height: Sp.x1),
      if (d.routines.isEmpty)
        Text('No routines yet. Something small you do on set days, like a walk or ten pages.', style: AllyType.body(color: c.muted))
      else
        AllyCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
          child: Column(
            children: [
              for (var k = 0; k < d.routines.length; k++) ...[
                if (k > 0) Divider(color: c.line, height: 1),
                _routineRow(c, d, d.routines[k]),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _routineRow(AllyColors c, WeekData d, WeekRoutine r) {
    final color = c.area(d.colorIndexOf(r.areaId));
    return Semantics(
      // One spoken line per routine, instead of seven unlabelled dots.
      container: true,
      button: true,
      label: '${r.title}, ${r.line}',
      excludeSemantics: true,
      onTap: () => _openRoutine(d, r),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openRoutine(d, r),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: Sp.x2,
                runSpacing: 2,
                children: [
                  Text(
                    r.title,
                    style: AllyType.body(color: c.ink, w: FontWeight.w500),
                  ),
                  Text(r.line, style: AllyType.small(color: c.faint)),
                ],
              ),
              const SizedBox(height: Sp.x2),
              Row(
                children: [
                  for (final dot in r.dots)
                    Expanded(
                      child: Center(
                        child: _Dot(kind: dot, color: color),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timePerArea(AllyColors c, WeekData d, List<WeekArea> areas) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('TIME PER AREA', style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x2),
      AllyCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
        child: Column(
          children: [
            for (final a in areas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: Sp.x2,
                      runSpacing: Sp.x1,
                      children: [
                        AreaLabel(a.name, color: c.area(d.colorIndexOf(a.id))),
                        Text(
                          a.plannedMinutes > 0 ? '${hoursLabel(a.minutes)} / ${hoursLabel(a.plannedMinutes)}' : hoursLabel(a.minutes),
                          style: AllyType.num(color: c.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.x2),
                    _Bar(
                      value: a.plannedMinutes > 0 ? a.minutes / a.plannedMinutes : (a.minutes > 0 ? 1 : 0),
                      color: c.area(d.colorIndexOf(a.id)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _lookBack(AllyColors c, WeekLookBack b) => AllyCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LOOKING BACK · ${b.month.toUpperCase()}', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: Sp.x2,
          children: [
            Text(hoursLabel(b.totalMinutes), style: AllyType.big(color: c.ink)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('on things you chose', style: AllyType.body(color: c.muted)),
            ),
          ],
        ),
        const SizedBox(height: Sp.x2),
        Text(b.byArea.map((x) => '${x.name} ${hoursLabel(x.minutes)}').join(' · '), style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x2),
        Text('Shown once a month. No scores, no streaks.', style: AllyType.small(color: c.faint)),
      ],
    ),
  );
}

/// Seven tappable bars, stacked by area. They grow in when the week appears.
class _Bars extends StatelessWidget {
  final WeekData data;
  final int selected;
  final ValueChanged<int> onSelect;
  const _Bars({required this.data, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final most = data.days.fold<int>(60, (m, d) => d.doneMinutes + d.plannedMinutes > m ? d.doneMinutes + d.plannedMinutes : m);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.days.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(i),
                selected: i == selected,
                semanticLabel:
                    '${data.days[i].label}: ${hoursLabel(data.days[i].doneMinutes)} done'
                    '${data.days[i].plannedMinutes > 0 ? ', ${hoursLabel(data.days[i].plannedMinutes)} planned' : ''}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Motion.of(context, Motion.d4 + Duration(milliseconds: 50 * i)),
                              curve: Motion.spring,
                              builder: (context, t, _) => FractionallySizedBox(
                                heightFactor: ((data.days[i].doneMinutes + data.days[i].plannedMinutes) / most * t).clamp(0.02, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    border: i == selected ? Border.all(color: c.ink, width: 2) : null,
                                  ),
                                  padding: EdgeInsets.all(i == selected ? 2 : 0),
                                  child: ClipRRect(borderRadius: BorderRadius.circular(7), child: _stack(c, data.days[i])),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Sp.x2),
                        Text(
                          data.days[i].label,
                          maxLines: 1,
                          style: AllyType.small(
                            color: i == selected ? c.ink : c.faint,
                            w: i == selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stack(AllyColors c, WeekDay d) {
    final parts = <(Color, int)>[
      for (final x in d.planned) (c.area(data.colorIndexOf(x.areaId)).withValues(alpha: 0.28), x.minutes),
      for (final x in d.done.reversed) (c.area(data.colorIndexOf(x.areaId)), x.minutes),
    ];
    if (parts.isEmpty) return ColoredBox(color: c.raised);
    return Column(
      children: [
        for (final (color, m) in parts)
          Expanded(
            flex: m < 1 ? 1 : m,
            child: ColoredBox(color: color, child: const SizedBox.expand()),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final String kind;
  final Color color;
  const _Dot({required this.kind, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    const size = 24.0;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: switch (kind) {
          'DONE' => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          'PLANNED' => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.faint, width: 1.5),
            ),
          ),
          // A day it was meant for that has gone: neutral, never red.
          'PAST' => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: c.raised,
              shape: BoxShape.circle,
              border: Border.all(color: c.line),
            ),
          ),
          _ => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.line, shape: BoxShape.circle),
          ),
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final Color color;
  const _Bar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      height: 7,
      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: Motion.of(context, Motion.d4),
        curve: Motion.ease,
        builder: (context, t, _) => FractionallySizedBox(
          widthFactor: t,
          child: Container(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}
