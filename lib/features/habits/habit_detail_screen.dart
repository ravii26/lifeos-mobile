import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/habit.dart';
import '../guide/guide_style.dart';
import '../shell/life_cubit.dart';
import 'habits_screen.dart' show openHabitForm;

class HabitDetailScreen extends StatelessWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        Habit? h;
        for (final x in s.habits) {
          if (x.id == habitId) h = x;
        }
        if (h == null) {
          return Scaffold(
            backgroundColor: G.bg,
            appBar: const GTopBar('Habit', showBack: true),
            body: Center(
              child:
                  Text('Habit not found', style: G.voice(15, color: G.muted)),
            ),
          );
        }
        final habit = h;
        final color = s.areaById(habit.areaId)?.color ?? G.accent;
        final completed = habit.history.where((d) => d).length;
        final rate = habit.history.isEmpty
            ? 0
            : (completed / habit.history.length * 100).round();

        return Scaffold(
          backgroundColor: G.bg,
          appBar: GTopBar(
            habit.title,
            subtitle: 'Habit continuity',
            showBack: true,
            trailing: IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: G.muted),
              onPressed: () => openHabitForm(context, habit: habit),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Row(
                children: [
                  _stat('${habit.currentStreak}', 'Days logged', G.good),
                  const SizedBox(width: 8),
                  _stat('${habit.longestStreak}', 'Best continuity', G.ink),
                  const SizedBox(width: 8),
                  _stat('$rate%', 'Consistency', G.accent),
                ],
              ),
              const SizedBox(height: 12),
              _logCard(context, habit, color),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _backfillDay(context, habit),
                  icon: Icon(Icons.history_rounded, size: 16, color: G.muted),
                  label: Text('Log a past day',
                      style: G.label(size: 11.5, color: G.muted)),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: G.card,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: G.lineSoft, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RECENT CONTINUITY',
                        style: G.label(size: 10.5, color: G.faint)),
                    const SizedBox(height: 12),
                    _Heatmap(history: habit.history, color: G.good),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: G.card,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: G.lineSoft, width: 0.5),
                ),
                child: Column(
                  children: [
                    _info('Frequency', habit.frequency),
                    const SizedBox(height: 8),
                    Container(height: 0.5, color: G.lineSoft),
                    const SizedBox(height: 8),
                    _info('Reminder', habit.reminderTime ?? 'Off'),
                    const SizedBox(height: 8),
                    Container(height: 0.5, color: G.lineSoft),
                    const SizedBox(height: 8),
                    _info(
                      'Target',
                      habit.kind == 'timer'
                          ? '${habit.targetMinutes}m focus'
                          : habit.kind == 'count'
                              ? '${habit.targetCount} count'
                              : 'Daily minimum (2 min counts)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String num, String label, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: G.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: G.lineSoft, width: 0.5),
          ),
          child: Column(
            children: [
              Text(num, style: G.numeral(24, color: c)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: G.label(size: 10, color: G.faint)),
            ],
          ),
        ),
      );

  Widget _logCard(BuildContext context, Habit h, Color color) {
    if (h.kind == 'boolean') {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TODAY', style: G.label(size: 10.5, color: G.faint)),
                Text(
                  h.todayDone ? 'Logged' : 'Pending',
                  style: G.label(
                    size: 11,
                    color: h.todayDone ? G.good : G.faint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => context.read<LifeCubit>().logHabit(h),
                icon: Icon(
                  h.todayDone ? Icons.check : Icons.add,
                  size: 16,
                  color: h.todayDone ? G.good : G.ink,
                ),
                label: Text(
                  h.todayDone ? 'Logged today (Tap to toggle)' : 'Mark as done',
                  style: G.text(13.5,
                      w: FontWeight.w500,
                      color: h.todayDone ? G.good : G.ink),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: h.todayDone
                      ? G.good.withValues(alpha: 0.12)
                      : G.inset,
                  side: BorderSide(
                    color: h.todayDone
                        ? G.good.withValues(alpha: 0.4)
                        : G.lineSoft,
                    width: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (h.kind == 'count') {
      final pct = h.target == 0 ? 0.0 : (h.todayCount / h.targetCount).clamp(0.0, 1.0);
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TODAY\'S COUNT',
                    style: G.label(size: 10.5, color: G.faint)),
                Text(
                  '${h.todayCount} / ${h.targetCount}',
                  style: G.label(
                      size: 11,
                      color: h.todayDone ? G.good : G.ink),
                ),
              ],
            ),
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
                    color: h.todayDone ? G.good : G.accent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: h.todayCount > 0
                      ? () {
                          final nextCount = h.todayCount - 1;
                          context.read<LifeCubit>().updateHabitLog(
                                h,
                                count: nextCount,
                                minutes: h.todayMinutes,
                                completed: nextCount >= h.targetCount,
                              );
                        }
                      : null,
                  icon: Icon(Icons.remove, size: 18, color: G.ink),
                  style: IconButton.styleFrom(
                    backgroundColor: G.inset,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: G.lineSoft, width: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Text('${h.todayCount}',
                    style: G.numeral(28, color: G.ink)),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: () {
                    final nextCount = h.todayCount + 1;
                    context.read<LifeCubit>().updateHabitLog(
                          h,
                          count: nextCount,
                          minutes: h.todayMinutes,
                          completed: nextCount >= h.targetCount,
                        );
                  },
                  icon: Icon(Icons.add, size: 18, color: G.accent),
                  style: IconButton.styleFrom(
                    backgroundColor: G.accent.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                          color: G.accent.withValues(alpha: 0.4), width: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Timer
    final pct = h.target == 0 ? 0.0 : (h.todayMinutes / h.targetMinutes).clamp(0.0, 1.0);
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TODAY\'S TIME',
                  style: G.label(size: 10.5, color: G.faint)),
              Text(
                '${h.todayMinutes} / ${h.targetMinutes}m',
                style: G.label(
                    size: 11,
                    color: h.todayDone ? G.good : G.ink),
              ),
            ],
          ),
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
                  color: h.todayDone ? G.good : G.accent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: h.todayMinutes >= 5
                    ? () {
                        final nextMin = h.todayMinutes - 5;
                        context.read<LifeCubit>().updateHabitLog(
                              h,
                              count: h.todayCount,
                              minutes: nextMin,
                              completed: nextMin >= h.targetMinutes,
                            );
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: G.lineSoft, width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: Text('-5m', style: G.label(size: 11, color: G.muted)),
              ),
              Text('${h.todayMinutes}m',
                  style: G.numeral(26, color: G.ink)),
              OutlinedButton(
                onPressed: () {
                  final nextMin = h.todayMinutes + 5;
                  context.read<LifeCubit>().updateHabitLog(
                        h,
                        count: h.todayCount,
                        minutes: nextMin,
                        completed: nextMin >= h.targetMinutes,
                      );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: G.accent.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: G.accent.withValues(alpha: 0.3), width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: Text('+5m', style: G.label(size: 11, color: G.accent)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _backfillDay(BuildContext context, Habit h) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Log a missed day',
    );
    if (picked == null || !context.mounted) return;

    if (h.kind == 'boolean') {
      context.read<LifeCubit>().backfillHabitLog(h, picked, completed: true);
      return;
    }

    final controller = TextEditingController();
    final unit = h.kind == 'timer' ? 'min' : 'count';
    final value = await showDialog<int>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: G.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        title: Text('${picked.month}/${picked.day} — how much?',
            style: G.voice(15, color: G.ink)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: G.text(14, color: G.ink),
          decoration: InputDecoration(
            hintText: 'e.g. ${h.target} ($unit)',
            hintStyle: G.text(14, color: G.faint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text('Cancel', style: G.label(size: 11.5, color: G.muted)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dctx).pop(int.tryParse(controller.text)),
            child: Text('Save', style: G.label(size: 11.5, color: G.accent)),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) return;
    context.read<LifeCubit>().backfillHabitLog(
          h,
          picked,
          completed: value >= h.target,
          count: h.kind == 'count' ? value : null,
          minutes: h.kind == 'timer' ? value : null,
        );
  }

  Widget _info(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: G.label(size: 11.5, color: G.faint)),
          Text(v, style: G.text(13, w: FontWeight.w500, color: G.ink)),
        ],
      );
}

class _Heatmap extends StatelessWidget {
  final List<bool> history;
  final Color color;
  const _Heatmap({required this.history, required this.color});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Text('No history recorded yet.',
          style: G.voice(13, color: G.faint));
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final done in history)
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: done ? color : G.inset,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: done ? Colors.transparent : G.lineSoft,
                width: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
