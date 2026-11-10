import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/links/open_link.dart';
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
            appBar: gBar(),
            body: Center(
              child: Text("Couldn't find this.", style: G.text(18, color: G.muted, height: 1.35)),
            ),
          );
        }
        final task = t;
        final area = s.areaById(task.areaId);
        final goal = s.goalById(task.goalId);
        final project = s.projectById(task.projectId);
        final color = area?.color ?? G.accent;
        final facts = <(String, String)>[
          if (task.dueDate != null) ('By', _fmtDate(task.dueDate!)),
          if (area != null) ('Part of life', area.name),
          if (goal != null) ('Goal', goal.title),
          if (project != null) ('Project', project.title),
          if (task.priorityLabel == 'P1') ('Importance', 'High'),
        ];

        return Scaffold(
          backgroundColor: G.bg,
          appBar: gBar(actions: [
            IconButton(
              tooltip: 'Edit',
              icon: Icon(Icons.edit_outlined, size: 23, color: G.ink),
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
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            children: [
              GTitle(task.title, size: 36, sub: task.isDone ? 'Done.' : null),
              if (facts.isNotEmpty)
                GCard(
                  child: Column(children: [
                    for (var i = 0; i < facts.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 108, child: Text(facts[i].$1, style: G.text(16, color: G.muted, height: 1.35))),
                          Expanded(child: Text(facts[i].$2, style: G.text(18, height: 1.3))),
                        ]),
                      ),
                  ]),
                ),
              if (_noteText(task).isNotEmpty)
                GCard(child: Text(_noteText(task), style: G.text(18, color: G.muted, height: 1.4))),
              // Made from a save: the video or post is one tap away.
              if (task.sourceUrl != null) OpenSourceButton(task.sourceUrl!),
              const SizedBox(height: 14),
              if (!task.isDone) ...[
                GPill('Start', primary: true, onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => FocusScreen(task: task, accentColor: color)),
                    )),
                const SizedBox(height: 10),
                GPill('Mark done', onTap: () {
                  context.read<LifeCubit>().completeTask(task.id);
                  Navigator.of(context).pop();
                }),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    context.read<LifeCubit>().deleteTask(task.id);
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
                  child: Text('Delete', style: G.text(17, height: 1.2)),
                ),
              ] else
                GPill('Not done yet', onTap: () {
                  context.read<LifeCubit>().completeTask(task.id);
                  Navigator.of(context).pop();
                }),
            ],
          ),
        );
      },
    );
  }

  // The description without its link ("From your save: …"); the link gets its own button.
  static String _noteText(Task t) {
    final url = t.sourceUrl;
    final text = t.description ?? '';
    return (url == null ? text : text.replaceAll(url, '')).trim();
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
