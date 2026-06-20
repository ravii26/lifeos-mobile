import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/user.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../focus/focus_screen.dart';
import '../shell/life_cubit.dart';
import '../tasks/task_row.dart';

class HomeScreen extends StatelessWidget {
  final AppUser user;
  final VoidCallback onOpenMore;
  const HomeScreen({super.key, required this.user, required this.onOpenMore});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greet = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        if (s.status == LoadStatus.loading || s.status == LoadStatus.initial) {
          return Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (s.status == LoadStatus.error) {
          return _ErrorView(
              message: s.error, onRetry: () => context.read<LifeCubit>().load());
        }

        final today = s.todayTasks;
        final doneToday = today.where((t) => t.isDone).length;
        final weakest = s.weakestArea;

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface2,
          onRefresh: () => context.read<LifeCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                eyebrow:
                    '${_weekday(now)} · ${_date(now)}',
                title: '$greet, ${user.firstName}.',
                avatarInitial: user.initial,
                onMore: onOpenMore,
                subtitle: RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 13, color: AppColors.tx3, height: 1.4),
                    children: [
                      const TextSpan(text: "You're "),
                      TextSpan(
                          text: '$doneToday/${today.length}',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' through today.'),
                      if (weakest != null) ...[
                        const TextSpan(text: ' Weakest area is '),
                        TextSpan(
                            text: weakest.name,
                            style: TextStyle(
                                color: weakest.color,
                                fontWeight: FontWeight.w600)),
                        const TextSpan(text: '.'),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (weakest != null) _hero(context, s, weakest),
                    const SizedBox(height: 14),
                    _momentumRow(s),
                    const SizedBox(height: 14),
                    SectionHeader('Life areas'),
                    const SizedBox(height: 12),
                    _areaStrip(s),
                    const SizedBox(height: 14),
                    SectionHeader('Today · $doneToday/${today.length}'),
                    const SizedBox(height: 10),
                    ..._taskList(context, s, today),
                    const SizedBox(height: 14),
                    SectionHeader('Quick log'),
                    const SizedBox(height: 10),
                    _habitsCard(context, s),
                    const SizedBox(height: 14),
                    SectionHeader('Inbox'),
                    const SizedBox(height: 10),
                    _inbox(context, s),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hero(BuildContext context, LifeState s, weakest) {
    final next = s.openTasks.isNotEmpty ? s.openTasks.first : null;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [weakest.color.withOpacity(0.18), AppColors.glassBg],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                AreaDot(weakest.color, size: 8, glow: true),
                const SizedBox(width: 6),
                Eyebrow('Next action', color: weakest.color),
              ]),
              Chip3('${weakest.name} · ${weakest.score}',
                  color: weakest.color, bg: AppColors.surface3),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            next?.title ?? "You're all caught up — capture something.",
            style: GoogleFonts.hankenGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.16,
                letterSpacing: -0.4,
                color: AppColors.tx),
          ),
          const SizedBox(height: 8),
          Text(
            next != null
                ? '${weakest.name} is your lowest-scoring area this week. Knock it out and watch the ring climb.'
                : 'Nothing pressing in your weakest area. Nice work.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.tx3, height: 1.5),
          ),
          if (next != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FocusScreen(
                            task: next, accentColor: weakest.color),
                      ),
                    ),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('Start now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentInk,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                OutlinedButton(
                  onPressed: () =>
                      context.read<LifeCubit>().completeTask(next.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tx,
                    side: BorderSide(color: AppColors.line2),
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Icon(Icons.check, size: 16),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _momentumRow(LifeState s) {
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Momentum'),
                const SizedBox(height: 8),
                Text('${s.avgScore}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: AppColors.tx)),
                const SizedBox(height: 4),
                Text('avg score',
                    style: TextStyle(fontSize: 12, color: AppColors.tx3)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Focus'),
                const SizedBox(height: 8),
                Text('0h',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: AppColors.tx)),
                const SizedBox(height: 4),
                Text('today', style: TextStyle(fontSize: 12, color: AppColors.tx3)),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _areaStrip(LifeState s) {
    if (s.areas.isEmpty) {
      return const _EmptyTile('No areas yet. Create one to start scoring.');
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: s.areas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (_, i) {
          final a = s.areas[i];
          return GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            radius: 16,
            child: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Donut(
                    value: a.score.toDouble(),
                    size: 60,
                    stroke: 6,
                    color: a.color,
                    center: Text('${a.score}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tx)),
                  ),
                  const SizedBox(height: 8),
                  Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: a.color)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _taskList(BuildContext context, LifeState s, List today) {
    if (today.isEmpty) {
      return const [_EmptyTile('Nothing scheduled. Capture something →')];
    }
    return [
      for (final t in today.take(4))
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: TaskRow(
            task: t,
            area: s.areaById(t.areaId),
            onComplete: () => context.read<LifeCubit>().completeTask(t.id),
            onDelete: () => context.read<LifeCubit>().deleteTask(t.id),
          ),
        ),
    ];
  }

  Widget _habitsCard(BuildContext context, LifeState s) {
    if (s.habits.isEmpty) {
      return const _EmptyTile('No habits yet.');
    }
    return GlassCard(
      child: Column(
        children: [
          for (final h in s.habits.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  AreaDot(s.areaById(h.areaId)?.color ?? AppColors.tx3, size: 9),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(h.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Text('${h.todayVal}/${h.target == 0 ? 1 : h.target}',
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5, color: AppColors.tx3)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          h.target == 0
                              ? (h.todayDone ? 1 : 0)
                              : h.todayVal / h.target,
                          color: s.areaById(h.areaId)?.color,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  GestureDetector(
                    onTap: () => context.read<LifeCubit>().logHabit(h),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                            h.todayDone ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: h.todayDone
                                ? AppColors.accent
                                : AppColors.line3,
                            width: 1.6),
                      ),
                      child: Icon(h.todayDone ? Icons.check : Icons.add,
                          size: 15,
                          color: h.todayDone
                              ? AppColors.accentInk
                              : AppColors.tx2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _inbox(BuildContext context, LifeState s) {
    final pending = s.pendingCaptures;
    if (pending.isEmpty) return const _EmptyTile('Inbox zero ✓');
    return Column(
      children: [
        for (final c in pending.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Chip3('${c.type} · ${c.confidencePct}%'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _weekday(DateTime d) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][d.weekday - 1];

  static String _date(DateTime d) => '${const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][d.month - 1]} ${d.day}';
}

class _EmptyTile extends StatelessWidget {
  final String text;
  const _EmptyTile(this.text);
  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(text,
              style: TextStyle(color: AppColors.tx4, fontSize: 13)),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const _ErrorView({this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 40, color: AppColors.tx3),
              const SizedBox(height: 14),
              Text(message ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.tx2)),
              const SizedBox(height: 8),
              Text('Is the backend running on the configured URL?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.tx4, fontSize: 12.5)),
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
