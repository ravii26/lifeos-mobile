import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/task.dart';
import '../focus/focus_screen.dart';
import '../guide/guide_style.dart';
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
            backgroundColor: G.bg,
            appBar: const GTopBar('Task', showBack: true),
            body: Center(
              child: Text('Task not found', style: G.voice(15, color: G.muted)),
            ),
          );
        }
        final task = t;
        final area = s.areaById(task.areaId);
        final goal = s.goalById(task.goalId);
        final project = s.projectById(task.projectId);
        final color = area?.color ?? G.accent;

        return Scaffold(
          backgroundColor: G.bg,
          appBar: GTopBar(
            'Task Detail',
            subtitle: task.isDone ? 'Completed' : 'Open action',
            showBack: true,
            trailing: IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: G.muted),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BlocProvider.value(
                  value: context.read<LifeCubit>(),
                  child: TaskForm(task: task, areas: s.areas),
                ),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                        if (task.priorityLabel.isNotEmpty &&
                            task.priorityLabel != 'NONE')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: G.inset,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: G.lineSoft, width: 0.5),
                            ),
                            child: Text(
                              task.priorityLabel,
                              style: G.label(size: 10, color: G.faint),
                            ),
                          ),
                        if (area != null) ...[
                          const SizedBox(width: 8),
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
                              Text(area.name,
                                  style: G.label(size: 11, color: color)),
                            ],
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: task.isDone
                                ? G.good.withValues(alpha: 0.15)
                                : G.inset,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: task.isDone
                                  ? G.good.withValues(alpha: 0.4)
                                  : G.lineSoft,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            task.isDone ? 'Completed' : 'Open',
                            style: G.label(
                              size: 10.5,
                              color: task.isDone ? G.good : G.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (goal != null || project != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (goal != null)
                            Text(
                              'Goal: ${goal.title}',
                              style: G.label(size: 11, color: G.faint),
                            ),
                          if (project != null)
                            Text(
                              'Project: ${project.title}',
                              style: G.label(size: 11, color: G.faint),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      task.title,
                      style: G.text(17, w: FontWeight.w500, color: G.ink),
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 13, color: G.faint),
                          const SizedBox(width: 6),
                          Text(_fmtDate(task.dueDate!),
                              style: G.label(size: 11.5, color: G.muted)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!task.isDone) ...[
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FocusScreen(task: task, accentColor: color),
                      ),
                    ),
                    icon: Icon(Icons.bolt, size: 16, color: G.accent),
                    label: Text('Start focus block',
                        style: G.text(13.5,
                            w: FontWeight.w500, color: G.accent)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: G.accent.withValues(alpha: 0.1),
                      side: BorderSide(
                          color: G.accent.withValues(alpha: 0.35), width: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
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
                        icon: Icon(Icons.check, size: 15, color: G.good),
                        label: Text('Mark done',
                            style: G.text(13,
                                w: FontWeight.w500, color: G.good)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          side: BorderSide(
                              color: G.good.withValues(alpha: 0.35), width: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
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
                        icon: Icon(Icons.delete_outline,
                            size: 15, color: G.carried),
                        label: Text('Delete',
                            style: G.text(13,
                                w: FontWeight.w500, color: G.carried)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          side: BorderSide(
                              color: G.carried.withValues(alpha: 0.35),
                              width: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<LifeCubit>().completeTask(task.id);
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.undo_rounded, size: 16, color: G.muted),
                    label: Text('Reopen task',
                        style: G.text(13,
                            w: FontWeight.w500, color: G.muted)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: G.lineSoft, width: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
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
