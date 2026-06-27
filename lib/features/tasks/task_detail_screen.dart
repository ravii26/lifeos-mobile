import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../focus/focus_screen.dart';
import '../shell/life_cubit.dart';
import 'task_form.dart';

class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        Task? t;
        for (final x in s.tasks) {
          if (x.id == taskId) t = x;
        }
        if (t == null) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: Text('Task not found')),
          );
        }
        final task = t;
        final area = s.areaById(task.areaId);
        final goal = s.goalById(task.goalId);
        final project = s.projectById(task.projectId);
        final color = area?.color ?? AppColors.accent;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const BackHeader(eyebrow: 'Task', title: 'Detail'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PriorityTag(task.priorityLabel),
                              const SizedBox(width: 8),
                              if (area != null)
                                Chip3(area.name,
                                    color: color,
                                    leading: AreaDot(color, size: 6)),
                              const Spacer(),
                              Chip3(task.isDone ? 'Done' : 'Open',
                                  color: task.isDone
                                      ? AppColors.ok
                                      : AppColors.tx2),
                            ],
                          ),
                          if (goal != null || project != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (goal != null)
                                  Chip3(goal.title,
                                      color: color,
                                      icon: Icons.flag_outlined),
                                if (project != null)
                                  Chip3(project.title,
                                      color: color,
                                      icon: Icons.assignment_outlined),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(task.title,
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25)),
                          if (task.dueDate != null) ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              Icon(Icons.event,
                                  size: 14, color: AppColors.tx3),
                              const SizedBox(width: 6),
                              Text(_fmtDate(task.dueDate!),
                                  style: TextStyle(
                                      fontSize: 12.5, color: AppColors.tx3)),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BlocProvider.value(
                            value: context.read<LifeCubit>(),
                            child: TaskForm(task: task, areas: s.areas),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit task'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: AppColors.tx,
                          side: BorderSide(color: AppColors.line2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!task.isDone) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FocusScreen(
                                  task: task, accentColor: color),
                            ),
                          ),
                          icon: const Icon(Icons.bolt, size: 18),
                          label: const Text('Start focus'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.accentInk,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context
                                    .read<LifeCubit>()
                                    .completeTask(task.id);
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Complete'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                foregroundColor: AppColors.tx,
                                side: BorderSide(color: AppColors.line2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.read<LifeCubit>().deleteTask(task.id);
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(
                                    color: Color(0x4DFF5D62)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.read<LifeCubit>().completeTask(task.id);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('Reopen task'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.tx,
                            side: BorderSide(color: AppColors.line2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.read<LifeCubit>().deleteTask(task.id);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete task'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: Color(0x4DFF5D62)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Due ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
