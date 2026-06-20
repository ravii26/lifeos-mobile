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
                    const SizedBox(height: 14),
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Eyebrow('Today'),
              Text(
                  h.kind == 'boolean'
                      ? (h.todayDone ? 'Done' : 'Not yet')
                      : '${h.todayVal}/${h.target}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 13, color: AppColors.tx2)),
            ],
          ),
          if (h.kind != 'boolean') ...[
            const SizedBox(height: 12),
            ProgressBar(pct, color: color),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => context.read<LifeCubit>().logHabit(h),
              icon: Icon(h.todayDone ? Icons.check : Icons.add, size: 18),
              label: Text(h.kind == 'count'
                  ? 'Log +1'
                  : h.kind == 'timer'
                      ? 'Log session'
                      : h.todayDone
                          ? 'Logged'
                          : 'Mark done'),
              style: FilledButton.styleFrom(
                backgroundColor: h.todayDone ? AppColors.surface3 : color,
                foregroundColor:
                    h.todayDone ? AppColors.tx : AppColors.accentInk,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
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
