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

class HabitsScreen extends StatelessWidget {
  final VoidCallback? onOpenMore;
  const HabitsScreen({super.key, this.onOpenMore});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        final logged = s.habits.where((h) => h.todayDone).length;
        final total = s.habits.length;

        return Scaffold(
          backgroundColor: G.bg,
          appBar: GTopBar(
            'Habits',
            subtitle: '$logged of $total logged today',
            showBack: true,
            trailing: IconButton(
              icon: Icon(Icons.add, size: 20, color: G.accent),
              onPressed: () => openHabitForm(context),
            ),
          ),
          body: RefreshIndicator(
            color: G.accent,
            backgroundColor: G.card,
            onRefresh: () => context.read<LifeCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: G.inset,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.repeat_rounded, size: 16, color: G.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No resets, no broken chains. Every 2-minute minimum counts and progress only accumulates.',
                          style: G.voice(13.5, color: G.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (s.habits.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'No habits tracked yet.\nCreate small repeated anchors to build effortless momentum.',
                        textAlign: TextAlign.center,
                        style: G.voice(14, color: G.muted),
                      ),
                    ),
                  )
                else
                  for (final h in s.habits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () {
                          final cubit = context.read<LifeCubit>();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: cubit,
                              child: HabitDetailScreen(habitId: h.id),
                            ),
                          ));
                        },
                        onLongPress: () => openHabitForm(context, habit: h),
                        child: _HabitCard(
                          habit: h,
                          areaColor: s.areaById(h.areaId)?.color,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final Color? areaColor;
  const _HabitCard({required this.habit, this.areaColor});

  @override
  Widget build(BuildContext context) {
    final h = habit;
    final color = areaColor ?? G.accent;
    final pct = h.target == 0
        ? (h.todayDone ? 1.0 : 0.0)
        : (h.todayVal / h.target).clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: G.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: G.lineSoft, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.read<LifeCubit>().logHabit(h),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: h.todayDone ? G.good : G.inset,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: h.todayDone ? G.good : G.lineSoft,
                      width: 0.8,
                    ),
                  ),
                  child: h.todayDone
                      ? Icon(Icons.check, size: 14, color: G.onInk)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: G.text(
                        14.5,
                        w: FontWeight.w500,
                        color: h.todayDone ? G.faint : G.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          h.kind == 'timer'
                              ? '${h.todayMinutes}/${h.targetMinutes} min'
                              : h.kind == 'count'
                                  ? '${h.todayCount}/${h.targetCount} today'
                                  : 'Daily rhythm',
                          style: G.label(size: 10.5, color: G.faint),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${h.currentStreak}d continuity',
                          style: G.label(size: 10.5, color: G.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (h.kind != 'boolean') ...[
            const SizedBox(height: 10),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: G.inset,
                borderRadius: BorderRadius.circular(1.5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: h.todayDone ? G.good : color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ],
          if (h.history.isNotEmpty) ...[
            const SizedBox(height: 10),
            _HistoryDots(history: h.history, color: color),
          ],
        ],
      ),
    );
  }
}

class _HistoryDots extends StatelessWidget {
  final List<bool> history;
  final Color color;
  const _HistoryDots({required this.history, required this.color});

  @override
  Widget build(BuildContext context) {
    final days = history.length > 21
        ? history.sublist(history.length - 21)
        : history;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final done in days)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: done ? G.good : G.lineSoft,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
      ],
    );
  }
}
