import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/habit.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends StatelessWidget {
  final VoidCallback onOpenMore;
  const HabitsScreen({super.key, required this.onOpenMore});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        final logged = s.habits.where((h) => h.todayDone).length;
        final best = s.habits.isEmpty
            ? 0
            : s.habits.map((h) => h.longestStreak).reduce((a, b) => a > b ? a : b);

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface2,
          onRefresh: () => context.read<LifeCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                eyebrow: 'Execution',
                title: 'Habits',
                avatarInitial: '·',
                onMore: onOpenMore,
                subtitle: Text(
                    '$logged/${s.habits.length} logged today · $best-day best streak'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _stat('$logged', 'Logged'),
                        const SizedBox(width: 10),
                        _stat('${s.habits.length}', 'Active'),
                        const SizedBox(width: 10),
                        _stat('$best', 'Best streak', accent: true),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (s.habits.isEmpty)
                      SurfaceCard(
                        padding: EdgeInsets.all(26),
                        child: Center(
                          child: Text('No habits yet.',
                              style: TextStyle(
                                  color: AppColors.tx4, fontSize: 13)),
                        ),
                      )
                    else
                      for (final h in s.habits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: _HabitCard(habit: h, areaColor: s.areaById(h.areaId)?.color),
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

  Widget _stat(String num, String label, {bool accent = false}) => Expanded(
        child: GlassCard(
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Text(num,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: accent ? AppColors.accent : AppColors.tx)),
              const SizedBox(height: 6),
              Eyebrow(label),
            ],
          ),
        ),
      );
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final Color? areaColor;
  const _HabitCard({required this.habit, this.areaColor});

  @override
  Widget build(BuildContext context) {
    final h = habit;
    final color = areaColor ?? AppColors.tx3;
    final pct = h.target == 0
        ? (h.todayDone ? 1.0 : 0.0)
        : (h.todayVal / h.target).clamp(0, 1).toDouble();

    return GlassCard(
      padding: const EdgeInsets.all(15),
      onTap: () {
        final cubit = context.read<LifeCubit>();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: HabitDetailScreen(habitId: h.id),
          ),
        ));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AreaDot(color, size: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(
                        h.kind == 'timer'
                            ? '${h.todayMinutes}/${h.targetMinutes} min'
                            : h.kind == 'count'
                                ? '${h.todayCount}/${h.targetCount} today'
                                : 'Daily',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.tx3)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.read<LifeCubit>().logHabit(h),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: h.todayDone ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color:
                            h.todayDone ? AppColors.accent : AppColors.line3,
                        width: 1.6),
                  ),
                  child: Icon(h.todayDone ? Icons.check : Icons.add,
                      size: 19,
                      color:
                          h.todayDone ? AppColors.accentInk : AppColors.tx2),
                ),
              ),
            ],
          ),
          if (h.kind != 'boolean') ...[
            const SizedBox(height: 13),
            ProgressBar(pct, color: color),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip3('${h.currentStreak}-day streak',
                  icon: Icons.local_fire_department,
                  color: AppColors.warn,
                  bg: const Color(0x1FFFB547)),
              Text('best ${h.longestStreak}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: AppColors.tx4)),
            ],
          ),
          if (h.history.isNotEmpty) ...[
            const SizedBox(height: 11),
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
    final days = history.length > 28
        ? history.sublist(history.length - 28)
        : history;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final done in days)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: done ? color : AppColors.surface3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
