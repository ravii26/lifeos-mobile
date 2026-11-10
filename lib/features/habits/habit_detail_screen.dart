import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/links/open_link.dart';
import '../../data/models/habit.dart';
import '../guide/guide_style.dart';
import '../shell/life_cubit.dart';
import 'habits_screen.dart' show habitWeekLine, openHabitForm;

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
            appBar: gBar(),
            body: Center(
              child: Text("Couldn't find this.", style: G.text(18, color: G.muted, height: 1.35)),
            ),
          );
        }
        final habit = h;

        return Scaffold(
          backgroundColor: G.bg,
          appBar: gBar(actions: [
            IconButton(
              tooltip: 'Edit',
              icon: Icon(Icons.edit_outlined, size: 23, color: G.ink),
              onPressed: () => openHabitForm(context, habit: habit),
            ),
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            children: [
              GTitle(habit.title, size: 36, sub: habitWeekLine(habit.history)),
              // Made from a save: the video or post is one tap away.
              if (habit.sourceUrl != null) OpenSourceButton(habit.sourceUrl!),
              _logCard(context, habit),
              Center(
                child: TextButton(
                  onPressed: () => _backfillDay(context, habit),
                  style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
                  child: Text('Add a day I missed logging', style: G.text(17, height: 1.2)),
                ),
              ),
              const SizedBox(height: 8),
              GCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent days', style: G.text(16, color: G.muted, height: 1.2)),
                    const SizedBox(height: 12),
                    _RecentDays(history: habit.history),
                  ],
                ),
              ),
              GCard(
                child: Column(
                  children: [
                    _info('How often', _title(habit.frequency)),
                    const SizedBox(height: 12),
                    _info('Reminder', habit.reminderTime ?? 'Off'),
                    const SizedBox(height: 12),
                    _info(
                      'Aim',
                      habit.kind == 'timer'
                          ? '${habit.targetMinutes} min'
                          : habit.kind == 'count'
                              ? '${habit.targetCount} a day'
                              : 'Even 2 minutes counts',
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

  static String _title(String s) => s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();

  Widget _bar(double pct) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: pct, minHeight: 8, color: G.accent, backgroundColor: G.surfaceHigh),
      );

  Widget _todayLine(String left, String right) => Row(
        children: [
          Expanded(child: Text(left, style: G.text(16, color: G.muted, height: 1.2))),
          Text(right, style: G.text(18, w: FontWeight.w500, height: 1.2)),
        ],
      );

  Widget _round(IconData icon, String tip, VoidCallback? onTap) => IconButton(
        tooltip: tip,
        onPressed: onTap,
        iconSize: 26,
        style: IconButton.styleFrom(
          backgroundColor: G.surfaceHigh,
          disabledBackgroundColor: G.surfaceHigh.withValues(alpha: 0.4),
          foregroundColor: G.ink,
          minimumSize: const Size(56, 56),
        ),
        icon: Icon(icon),
      );

  Widget _logCard(BuildContext context, Habit h) {
    if (h.kind == 'boolean') {
      return GPill(h.todayDone ? 'Done today. Tap to undo' : 'Mark done', primary: !h.todayDone, onTap: () => context.read<LifeCubit>().logHabit(h));
    }

    if (h.kind == 'count') {
      final pct = h.target == 0 ? 0.0 : (h.todayCount / h.targetCount).clamp(0.0, 1.0);
      void setCount(int n) => context.read<LifeCubit>().updateHabitLog(h, count: n, minutes: h.todayMinutes, completed: n >= h.targetCount);
      return GCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _todayLine('Today', '${h.todayCount} of ${h.targetCount}'),
            const SizedBox(height: 12),
            _bar(pct),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _round(Icons.remove_rounded, 'One less', h.todayCount > 0 ? () => setCount(h.todayCount - 1) : null),
                const SizedBox(width: 24),
                Text('${h.todayCount}', style: G.numeral(42)),
                const SizedBox(width: 24),
                _round(Icons.add_rounded, 'One more', () => setCount(h.todayCount + 1)),
              ],
            ),
          ],
        ),
      );
    }

    // Minutes
    final pct = h.target == 0 ? 0.0 : (h.todayMinutes / h.targetMinutes).clamp(0.0, 1.0);
    void setMinutes(int n) => context.read<LifeCubit>().updateHabitLog(h, count: h.todayCount, minutes: n, completed: n >= h.targetMinutes);
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _todayLine('Today', '${h.todayMinutes} of ${h.targetMinutes} min'),
          const SizedBox(height: 12),
          _bar(pct),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _round(Icons.remove_rounded, '5 minutes less', h.todayMinutes >= 5 ? () => setMinutes(h.todayMinutes - 5) : null),
              const SizedBox(width: 24),
              Text('${h.todayMinutes}', style: G.numeral(42)),
              const SizedBox(width: 24),
              _round(Icons.add_rounded, '5 minutes more', () => setMinutes(h.todayMinutes + 5)),
            ],
          ),
          const SizedBox(height: 8),
          Center(child: Text('Each tap is 5 minutes', style: G.text(15, color: G.muted, height: 1.3))),
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
      helpText: 'Which day?',
    );
    if (picked == null || !context.mounted) return;

    if (h.kind == 'boolean') {
      context.read<LifeCubit>().backfillHabitLog(h, picked, completed: true);
      return;
    }

    final controller = TextEditingController();
    final unit = h.kind == 'timer' ? 'minutes' : 'times';
    final value = await showDialog<int>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: G.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('How much that day?', style: G.text(26, w: FontWeight.w600, height: 1.15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          cursorColor: G.accent,
          style: G.text(18, height: 1.3),
          decoration: InputDecoration(
            hintText: 'Like ${h.target} $unit',
            hintStyle: G.text(18, color: G.faint, height: 1.3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
            child: Text('Cancel', style: G.text(17, height: 1.2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(int.tryParse(controller.text)),
            style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 48)),
            child: Text('Save', style: G.text(17, w: FontWeight.w600, color: G.accent, height: 1.2)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 108, child: Text(k, style: G.text(16, color: G.muted, height: 1.35))),
          Expanded(child: Text(v, style: G.text(18, height: 1.3))),
        ],
      );
}

/// One small square per recent day. Peach when it happened, and never a count.
class _RecentDays extends StatelessWidget {
  final List<bool> history;
  const _RecentDays({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Text('Nothing logged yet.', style: G.text(17, color: G.muted, height: 1.35));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final done in history)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: done ? G.accent : G.surfaceHigh, borderRadius: BorderRadius.circular(6)),
          ),
      ],
    );
  }
}
