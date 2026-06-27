import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_row.dart';

class AreaDetailScreen extends StatefulWidget {
  final String areaId;
  const AreaDetailScreen({super.key, required this.areaId});

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget behaviour signal — powers the coach's neglect detection.
    getIt<LifeRepository>().recordBehavior('AREA_VIEWED',
        metadata: {'areaId': widget.areaId}).ignore();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        Area? a;
        for (final x in s.areas) {
          if (x.id == widget.areaId) a = x;
        }
        if (a == null) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: Text('Area not found')),
          );
        }
        final area = a;
        final tasks =
            s.openTasks.where((t) => t.areaId == area.id).toList();
        final habits =
            s.habits.where((h) => h.areaId == area.id).toList();

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              BackHeader(
                  eyebrow: area.type == 'PRIMARY' ? 'Primary area' : 'Area',
                  title: area.name,
                  color: area.color),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Donut(
                            value: area.score.toDouble(),
                            size: 84,
                            stroke: 7,
                            color: area.color,
                            center: Text('${area.score}',
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.tx)),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip3('${area.tasksDone}/${area.tasksTotal} tasks'),
                                Chip3('${area.streak}d streak',
                                    icon: Icons.local_fire_department),
                                Chip3('${area.focusMins}m focus'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader('Open tasks · ${tasks.length}'),
                    const SizedBox(height: 10),
                    if (tasks.isEmpty)
                      const _Empty('No open tasks in this area.')
                    else
                      for (final t in tasks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: GestureDetector(
                            onTap: () {
                              final cubit = context.read<LifeCubit>();
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: cubit,
                                  child: TaskDetailScreen(taskId: t.id),
                                ),
                              ));
                            },
                            child: TaskRow(
                              task: t,
                              area: area,
                              onComplete: () =>
                                  context.read<LifeCubit>().completeTask(t.id),
                              onDelete: () =>
                                  context.read<LifeCubit>().deleteTask(t.id),
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),
                    SectionHeader('Habits · ${habits.length}'),
                    const SizedBox(height: 10),
                    if (habits.isEmpty)
                      const _Empty('No habits in this area.')
                    else
                      for (final h in habits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                AreaDot(area.color, size: 9),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Text(h.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                ),
                                Chip3('${h.currentStreak}d',
                                    icon: Icons.local_fire_department),
                              ],
                            ),
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
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: Text(text,
                style: TextStyle(color: AppColors.tx4, fontSize: 13))),
      );
}
