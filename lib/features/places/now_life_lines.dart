import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/links/open_link.dart';
import '../guide/guide_style.dart';
import 'now_cubit.dart';
import 'now_extras.dart';

/// The quiet lines under the main pick on Now: a running timer with Stop, today's
/// counts with +1, the routine for this part of the day as a checklist, the next
/// meal, and one Watch later suggestion when there is room. Nothing here counts
/// against you; each line only shows when it applies.
class NowLifeLines extends StatelessWidget {
  final NowExtras extras;
  final bool busy;
  const NowLifeLines({super.key, required this.extras, required this.busy});

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) return const SizedBox.shrink();
    final cubit = context.read<NowCubit>();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (extras.timer != null) _timer(extras.timer!, cubit),
        if (extras.counts.isNotEmpty) _counts(extras.counts, cubit),
        if (extras.routine != null) _routine(extras.routine!, cubit),
        if (extras.meal != null) _meal(extras.meal!),
        if (extras.later != null) _later(context, extras.later!, cubit),
      ]),
    );
  }

  Widget _box({required Widget child, Color? edge}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: G.inset,
          border: Border(left: BorderSide(color: edge ?? G.lineSoft, width: edge == null ? 0.5 : 2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );

  Widget _timer(NowTimer t, NowCubit cubit) => _box(
        edge: G.accent,
        child: Row(children: [
          Icon(Icons.timer_outlined, size: 18, color: G.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t.label} · ${t.length}', style: G.text(14, w: FontWeight.w600)),
              if (t.forgotten) Text('Running a long time. Tell me how long it really was.', style: G.label(size: 11, color: G.faint)),
            ]),
          ),
          TextButton(
            onPressed: busy ? null : cubit.stopTimer,
            child: Text('Stop', style: G.text(14, w: FontWeight.w700, color: G.accent)),
          ),
        ]),
      );

  Widget _counts(List<NowCount> counts, NowCubit cubit) => _box(
        child: Column(children: [
          for (final c in counts.take(3))
            Row(children: [
              Expanded(child: Text(c.line, style: G.text(14, w: FontWeight.w500))),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '+1 ${c.title}',
                onPressed: busy ? null : () => cubit.addCount(c.id),
                icon: Icon(Icons.add_circle_outline_rounded, color: G.good),
              ),
            ]),
        ]),
      );

  Widget _routine(NowRoutine r, NowCubit cubit) => _box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.title, style: G.text(14, w: FontWeight.w600))),
            Text(r.remaining == 0 ? 'All done' : '${r.remaining} left', style: G.label(size: 11, color: G.faint)),
          ]),
          const SizedBox(height: 4),
          for (final s in r.steps)
            InkWell(
              onTap: busy ? null : () => cubit.tickStep(r.id, s.text, !s.done),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(s.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20, color: s.done ? G.good : G.faint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.text,
                        style: G.text(14, color: s.done ? G.faint : G.ink).copyWith(decoration: s.done ? TextDecoration.lineThrough : null)),
                  ),
                ]),
              ),
            ),
          if (r.remaining == 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : () => cubit.resetRoutine(r.id),
                child: Text('Start again', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
              ),
            ),
        ]),
      );

  Widget _meal(NowMeal m) => _box(
        child: Row(children: [
          Icon(Icons.restaurant_outlined, size: 18, color: G.faint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.label, style: G.label(size: 11, color: G.faint)),
              Text(m.text, style: G.text(14, w: FontWeight.w500)),
            ]),
          ),
        ]),
      );

  Widget _later(BuildContext context, NowLater l, NowCubit cubit) => _box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.line, style: G.text(14, height: 1.35)),
          const SizedBox(height: 4),
          Row(children: [
            if (l.url != null)
              TextButton(
                onPressed: () => openLink(context, l.url!),
                child: Text('Open', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
              ),
            TextButton(
              onPressed: busy ? null : () => cubit.watched(l.id),
              child: Text('Watched', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
            ),
            TextButton(
              onPressed: busy ? null : () => cubit.hideLater(l.id),
              child: Text('Not now', style: G.label(size: 12, color: G.muted, w: FontWeight.w600)),
            ),
          ]),
        ]),
      );
}
