import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/habit.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';

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
            backgroundColor: AppColors.bg,
            body: Center(child: Text('Habit not found')),
          );
        }
        final habit = h;
        final color = s.areaById(habit.areaId)?.color ?? AppColors.accent;
        final completed = habit.history.where((d) => d).length;
        final rate = habit.history.isEmpty
            ? 0
            : (completed / habit.history.length * 100).round();

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              BackHeader(
                  eyebrow: 'Habit',
                  title: habit.title,
                  color: color),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _stat('${habit.currentStreak}', 'Current', color),
                        const SizedBox(width: 10),
                        _stat('${habit.longestStreak}', 'Best', color),
                        const SizedBox(width: 10),
                        _stat('$rate%', '28-day', color),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _logCard(context, habit, color),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _backfillDay(context, habit),
                        icon: const Icon(Icons.event_available, size: 16),
                        label: const Text('Log a missed day'),
                        style: TextButton.styleFrom(foregroundColor: color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow('Last ${habit.history.length} days'),
                          const SizedBox(height: 14),
                          _Heatmap(history: habit.history, color: color),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Column(
                        children: [
                          _info('Frequency', habit.frequency),
                          const Divider(height: 18),
                          _info('Reminder', habit.reminderTime ?? 'Off'),
                          const Divider(height: 18),
                          _info(
                              'Type',
                              habit.kind == 'timer'
                                  ? 'Timer · ${habit.targetMinutes}m'
                                  : habit.kind == 'count'
                                      ? 'Count · ${habit.targetCount}'
                                      : 'Daily check'),
                        ],
                      ),
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

  Widget _stat(String num, String label, Color color) => Expanded(
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Text(num,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: color)),
              const SizedBox(height: 6),
              Eyebrow(label),
            ],
          ),
        ),
      );

  Widget _logCard(BuildContext context, Habit h, Color color) {
    final pct = h.target == 0
        ? (h.todayDone ? 1.0 : 0.0)
        : (h.todayVal / h.target).clamp(0, 1).toDouble();

    if (h.kind == 'boolean') {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Eyebrow('Today'),
                Text(
                    h.todayDone ? 'Done' : 'Not yet',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        color: h.todayDone ? AppColors.ok : AppColors.tx3)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => context.read<LifeCubit>().logHabit(h),
                icon: Icon(h.todayDone ? Icons.check : Icons.add, size: 18),
                label: Text(h.todayDone ? 'Logged (Tap to uncheck)' : 'Mark done'),
                style: FilledButton.styleFrom(
                  backgroundColor: h.todayDone ? AppColors.ok.withValues(alpha: 0.15) : color,
                  foregroundColor: h.todayDone ? AppColors.ok : AppColors.accentInk,
                  side: h.todayDone ? BorderSide(color: AppColors.ok.withValues(alpha: 0.3)) : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (h.kind == 'count') {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Eyebrow('Today\'s Count'),
                Text(
                    '${h.todayCount}/${h.targetCount}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                        color: h.todayDone ? AppColors.ok : AppColors.tx)),
              ],
            ),
            const SizedBox(height: 12),
            ProgressBar(pct, color: h.todayDone ? AppColors.ok : color),
            const SizedBox(height: 20),
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
                  icon: const Icon(Icons.remove, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface3,
                    foregroundColor: AppColors.tx,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  '${h.todayCount}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tx,
                  ),
                ),
                const SizedBox(width: 24),
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
                  icon: const Icon(Icons.add, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: AppColors.accentInk,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (h.todayCount > 0)
              Center(
                child: TextButton(
                  onPressed: () {
                    context.read<LifeCubit>().updateHabitLog(
                      h,
                      count: 0,
                      minutes: h.todayMinutes,
                      completed: false,
                    );
                  },
                  child: Text(
                    'Reset Count',
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Timer kind
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Eyebrow('Today\'s Timer'),
              Text(
                  '${h.todayMinutes}/${h.targetMinutes} min',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      color: h.todayDone ? AppColors.ok : AppColors.tx)),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(pct, color: h.todayDone ? AppColors.ok : color),
          const SizedBox(height: 20),
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
                  foregroundColor: AppColors.tx2,
                  side: BorderSide(color: AppColors.line2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('-5m'),
              ),
              OutlinedButton(
                onPressed: h.todayMinutes >= 15
                    ? () {
                        final nextMin = h.todayMinutes - 15;
                        context.read<LifeCubit>().updateHabitLog(
                          h,
                          count: h.todayCount,
                          minutes: nextMin,
                          completed: nextMin >= h.targetMinutes,
                        );
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tx2,
                  side: BorderSide(color: AppColors.line2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('-15m'),
              ),
              Text(
                '${h.todayMinutes}m',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tx,
                ),
              ),
              FilledButton(
                onPressed: () {
                  final nextMin = h.todayMinutes + 5;
                  context.read<LifeCubit>().updateHabitLog(
                    h,
                    count: h.todayCount,
                    minutes: nextMin,
                    completed: nextMin >= h.targetMinutes,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface3,
                  foregroundColor: AppColors.tx,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('+5m'),
              ),
              FilledButton(
                onPressed: () {
                  final nextMin = h.todayMinutes + 15;
                  context.read<LifeCubit>().updateHabitLog(
                    h,
                    count: h.todayCount,
                    minutes: nextMin,
                    completed: nextMin >= h.targetMinutes,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AppColors.accentInk,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('+15m'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (h.todayMinutes > 0)
            Center(
              child: TextButton(
                onPressed: () {
                  context.read<LifeCubit>().updateHabitLog(
                    h,
                    count: h.todayCount,
                    minutes: 0,
                    completed: false,
                  );
                },
                child: Text(
                  'Reset Timer',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
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
        backgroundColor: AppColors.surface2,
        title: Text('${picked.month}/${picked.day} — how much?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: 'e.g. ${h.target} ($unit)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.of(dctx).pop(int.tryParse(controller.text)),
            child: const Text('Save'),
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
          Text(k, style: TextStyle(color: AppColors.tx3, fontSize: 13.5)),
          Text(v,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        ],
      );
}

/// GitHub-style contribution grid for the habit's recent history.
class _Heatmap extends StatelessWidget {
  final List<bool> history;
  final Color color;
  const _Heatmap({required this.history, required this.color});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Text('No history yet.',
          style: TextStyle(color: AppColors.tx4, fontSize: 12.5));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final done in history)
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? color : AppColors.surface3,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }
}
