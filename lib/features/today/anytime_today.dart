import 'package:flutter/material.dart';

import '../../core/links/open_link.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart';
import '../places/now_extras.dart';

/// "Anytime today" on Today: the small things that belong to the day but not
/// to a time. A running timer with Stop, counts with +1, the routine for this
/// part of the day as a checklist, the next meal, and one saved video when
/// there is room. Each line shows only when it applies; nothing here counts
/// against anyone. Loose to-dos with no time are already on today's list.
class AnytimeToday extends StatelessWidget {
  final NowExtras extras;
  final bool busy;
  final NowCubit cubit;

  const AnytimeToday({super.key, required this.extras, required this.busy, required this.cubit});

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) return const SizedBox.shrink();
    final c = context.ac;
    final rows = <Widget>[
      if (extras.timer != null) _timer(c, extras.timer!),
      for (final n in extras.counts.take(3)) _count(c, n),
      if (extras.meal != null) _meal(c, extras.meal!),
      if (extras.later != null) _later(context, c, extras.later!),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('ANYTIME TODAY', style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x3),
      if (rows.isNotEmpty)
        AllyCard(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x1, Sp.x2, Sp.x1),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(color: c.line, height: 1),
              rows[i],
            ],
          ]),
        ),
      if (extras.routine != null) ...[
        if (rows.isNotEmpty) const SizedBox(height: Sp.x3),
        _routine(c, extras.routine!),
      ],
    ]);
  }

  Widget _row({required Widget lead, required Widget trailing}) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(children: [
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: Sp.x2), child: lead)),
          const SizedBox(width: Sp.x2),
          trailing,
        ]),
      );

  Widget _two(AllyColors c, String top, String? under) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(top, style: AllyType.body(color: c.ink, w: FontWeight.w500)),
        if (under != null) Text(under, style: AllyType.small(color: c.faint)),
      ]);

  Widget _timer(AllyColors c, NowTimer t) => _row(
        lead: Row(children: [
          Icon(Icons.timer_outlined, size: 20, color: c.muted),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: _two(c, '${t.label} · ${t.length}',
                t.forgotten ? 'Running a long time. Stop it and say how long it really was.' : 'Timer running'),
          ),
        ]),
        trailing: AllyButton('Stop', kind: AllyButtonKind.secondary, onPressed: busy ? null : cubit.stopTimer),
      );

  Widget _count(AllyColors c, NowCount n) => _row(
        lead: _two(c, n.title, n.target == null ? '${n.count} today' : '${n.count} of ${n.target}'),
        trailing: AllyButton('+1',
            kind: AllyButtonKind.secondary,
            semanticLabel: 'Add one: ${n.title}',
            onPressed: busy ? null : () => cubit.addCount(n.id)),
      );

  Widget _meal(AllyColors c, NowMeal m) => _row(
        lead: Row(children: [
          Icon(Icons.restaurant_outlined, size: 20, color: c.muted),
          const SizedBox(width: Sp.x3),
          Expanded(child: _two(c, m.text, m.label)),
        ]),
        trailing: const SizedBox.shrink(),
      );

  Widget _later(BuildContext context, AllyColors c, NowLater l) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.x2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.play_circle_outline_rounded, size: 20, color: c.muted),
            const SizedBox(width: Sp.x3),
            Expanded(child: Text(l.line, style: AllyType.body(color: c.ink))),
          ]),
          Wrap(spacing: Sp.x1, children: [
            if (l.url != null) AllyButton('Open', kind: AllyButtonKind.ghost, onPressed: () => openLink(context, l.url!)),
            AllyButton('Watched', kind: AllyButtonKind.ghost, onPressed: busy ? null : () => cubit.watched(l.id)),
            AllyButton('Not now', kind: AllyButtonKind.ghost, onPressed: busy ? null : () => cubit.hideLater(l.id)),
          ]),
        ]),
      );

  Widget _routine(AllyColors c, NowRoutine r) => AllyCard(
        padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x1, Sp.x2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(r.title, style: AllyType.body(color: c.ink, w: FontWeight.w600))),
            Padding(
              padding: const EdgeInsets.only(right: Sp.x3),
              child: Text(r.remaining == 0 ? 'All done' : '${r.remaining} left', style: AllyType.num(color: c.faint, size: 12)),
            ),
          ]),
          for (final s in r.steps)
            Row(children: [
              Expanded(
                child: Text(
                  s.text,
                  style: AllyType.body(color: s.done ? c.faint : c.ink)
                      .copyWith(decoration: s.done ? TextDecoration.lineThrough : null),
                ),
              ),
              // A step can be unticked too: a routine is a checklist, not a record.
              AllyCheck(done: s.done, semanticLabel: s.text, onTap: busy ? null : () => cubit.tickStep(r.id, s.text, !s.done)),
            ]),
          if (r.remaining == 0)
            Align(
              alignment: Alignment.centerLeft,
              child: AllyButton('Start again', kind: AllyButtonKind.ghost, onPressed: busy ? null : () => cubit.resetRoutine(r.id)),
            ),
        ]),
      );
}
