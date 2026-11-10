import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/habit.dart';
import '../guide/guide_style.dart';
import '../shell/life_cubit.dart';
import 'habit_detail_screen.dart';
import 'habit_form.dart';

void openHabitForm(BuildContext context, {Habit? habit}) {
  final cubit = context.read<LifeCubit>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: HabitForm(habit: habit, areas: cubit.state.areas),
    ),
  );
}

/// "5 of the last 7 days": a count that only adds up, so a missed day breaks nothing.
String habitWeekLine(List<bool> history) {
  if (history.isEmpty) return 'Just started';
  final days = history.length > 7 ? history.sublist(history.length - 7) : history;
  final done = days.where((d) => d).length;
  return '$done of the last ${days.length} days';
}

class HabitsScreen extends StatelessWidget {
  final VoidCallback? onOpenMore;
  const HabitsScreen({super.key, this.onOpenMore});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) => Scaffold(
        backgroundColor: G.bg,
        body: RefreshIndicator(
          color: G.accent,
          backgroundColor: G.card,
          onRefresh: () => context.read<LifeCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
            children: [
              Row(children: [
                Expanded(child: Text('Habits', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3))),
                IconButton(
                  tooltip: 'Add a habit',
                  onPressed: () => openHabitForm(context),
                  icon: Icon(Icons.add_rounded, color: G.ink),
                  style: IconButton.styleFrom(backgroundColor: G.card, minimumSize: const Size(46, 46)),
                ),
              ]),
              const SizedBox(height: 8),
              Text('The small version always counts.', style: G.text(19, color: G.muted, height: 1.3)),
              const SizedBox(height: 18),
              if (s.habits.isEmpty) ...[
                Text('No habits yet. Start with something tiny.', style: G.text(19, color: G.muted, height: 1.35)),
                const SizedBox(height: 18),
                GPill('Add a habit', primary: true, onTap: () => openHabitForm(context)),
              ] else
                for (final h in s.habits) _HabitRow(habit: h),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final Habit habit;
  const _HabitRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    final h = habit;
    final today = h.kind == 'timer'
        ? '${h.todayMinutes} of ${h.targetMinutes} min today'
        : h.kind == 'count'
            ? '${h.todayCount} of ${h.targetCount} today'
            : habitWeekLine(h.history);
    return InkWell(
      onTap: () {
        final cubit = context.read<LifeCubit>();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BlocProvider.value(value: cubit, child: HabitDetailScreen(habitId: h.id)),
        ));
      },
      onLongPress: () => openHabitForm(context, habit: h),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.lineSoft))),
        child: Row(children: [
          Semantics(
            button: true,
            label: h.todayDone ? '${h.title} is done today' : 'Mark ${h.title} done',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.read<LifeCubit>().logHabit(h),
              child: SizedBox(
                width: 46,
                height: 60,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: h.todayDone ? G.accent : Colors.transparent, border: h.todayDone ? null : Border.all(color: G.faint, width: 2)),
                    child: h.todayDone ? Icon(Icons.check_rounded, size: 19, color: G.onInk) : null,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(20, height: 1.25)),
                const SizedBox(height: 2),
                Text(today, style: G.text(15, color: G.muted, height: 1.25)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
