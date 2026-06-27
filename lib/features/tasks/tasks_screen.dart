import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';
import 'task_detail_screen.dart';
import 'task_form.dart';
import 'task_row.dart';

class TasksScreen extends StatefulWidget {
  final VoidCallback onOpenMore;
  const TasksScreen({super.key, required this.onOpenMore});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _lane = 'today'; // today | backlog | done
  bool _adding = false;
  final _title = TextEditingController();
  String _priority = 'P2';
  String? _areaId;
  String? _goalId;
  String? _projectId;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<Task> _laneTasks(LifeState s) {
    final now = DateTime.now();
    bool isToday(Task t) {
      final d = t.dueDate;
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }

    return switch (_lane) {
      'done' => s.doneTasks,
      'backlog' => s.openTasks.where((t) => !isToday(t)).toList(),
      _ => s.openTasks.where(isToday).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        final list = _laneTasks(s);
        final counts = {
          'today': s.openTasks
              .where((t) =>
                  t.dueDate != null &&
                  DateUtils.isSameDay(t.dueDate, DateTime.now()))
              .length,
          'backlog': s.openTasks.length,
          'done': s.doneTasks.length,
        };

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface2,
          onRefresh: () => context.read<LifeCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                eyebrow: 'Execution',
                title: 'Tasks',
                avatarInitial: '·',
                onMore: widget.onOpenMore,
                subtitle: Text(
                    '${counts['today']} due today · ${counts['backlog']} open'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _segmented(counts),
                    const SizedBox(height: 14),
                    if (!_adding && _lane != 'done')
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _adding = true),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add task'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: AppColors.tx,
                          side: BorderSide(color: AppColors.line2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    if (_adding) _addTaskCard(context, s),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      SurfaceCard(
                        padding: const EdgeInsets.all(26),
                        child: Center(
                          child: Text(
                            _lane == 'done'
                                ? 'Complete a task to see it here.'
                                : _lane == 'backlog'
                                    ? 'Backlog is clear.'
                                    : 'Nothing for today.',
                            style: TextStyle(
                                color: AppColors.tx4, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      for (final t in list)
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
                            onLongPress: () {
                              final cubit = context.read<LifeCubit>();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => BlocProvider.value(
                                  value: cubit,
                                  child: TaskForm(task: t, areas: s.areas),
                                ),
                              );
                            },
                            child: TaskRow(
                              task: t,
                              area: s.areaById(t.areaId),
                              onComplete: () =>
                                  context.read<LifeCubit>().completeTask(t.id),
                              onDelete: () =>
                                  context.read<LifeCubit>().deleteTask(t.id),
                            ),
                          ),
                        ),
                    const SizedBox(height: 6),
                    Text('Swipe right to complete · left to delete',
                        style: TextStyle(color: AppColors.tx4, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _segmented(Map<String, int> counts) {
    Widget seg(String id, String label) {
      final on = _lane == id;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _lane = id),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? AppColors.surface4 : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text('$label  ${counts[id]}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? AppColors.tx : AppColors.tx3)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        seg('today', 'Today'),
        seg('backlog', 'Backlog'),
        seg('done', 'Done'),
      ]),
    );
  }

  Widget _addTaskCard(BuildContext context, LifeState s) {
    final linkableGoals =
        s.goals.where((g) => _areaId == null || g.areaId == _areaId).toList();
    final linkableProjects = s.projects.where((p) {
      if (_areaId == null) return false;
      if (_goalId != null) {
        return p.goalId == _goalId;
      } else {
        return p.areaId == _areaId;
      }
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              style: TextStyle(fontSize: 15, color: AppColors.tx),
              decoration: const InputDecoration(hintText: 'What needs doing?'),
            ),
            const SizedBox(height: 11),
            if (s.areas.isNotEmpty)
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: s.areas.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final on = _areaId == null;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _areaId = null;
                          _goalId = null;
                          _projectId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: on ? AppColors.accent : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    on ? Colors.transparent : AppColors.line),
                          ),
                          child: Text('No Area',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? AppColors.accentInk
                                      : AppColors.tx2)),
                        ),
                      );
                    }
                    final a = s.areas[i - 1];
                    final on = _areaId == a.id;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _areaId = a.id;
                        if (_goalId != null) {
                          final hasGoal = s.goals.any(
                              (g) => g.id == _goalId && g.areaId == a.id);
                          if (!hasGoal) {
                            _goalId = null;
                            _projectId = null;
                          }
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: on ? AppColors.accent : AppColors.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: on ? Colors.transparent : AppColors.line),
                        ),
                        child: Text(a.name,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: on
                                    ? AppColors.accentInk
                                    : AppColors.tx2)),
                      ),
                    );
                  },
                ),
              ),
            if (_areaId != null && linkableGoals.isNotEmpty) ...[
              const SizedBox(height: 11),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: linkableGoals.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final on = _goalId == null;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _goalId = null;
                          _projectId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: on ? AppColors.accent : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    on ? Colors.transparent : AppColors.line),
                          ),
                          child: Text('No Goal',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? AppColors.accentInk
                                      : AppColors.tx2)),
                        ),
                      );
                    }
                    final g = linkableGoals[i - 1];
                    final on = _goalId == g.id;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _goalId = g.id;
                        if (_projectId != null) {
                          final hasProj = s.projects.any(
                              (p) => p.id == _projectId && p.goalId == g.id);
                          if (!hasProj) _projectId = null;
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: on ? AppColors.accent : AppColors.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: on ? Colors.transparent : AppColors.line),
                        ),
                        child: Text(g.title,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: on
                                    ? AppColors.accentInk
                                    : AppColors.tx2)),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_areaId != null && linkableProjects.isNotEmpty) ...[
              const SizedBox(height: 11),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: linkableProjects.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final on = _projectId == null;
                      return GestureDetector(
                        onTap: () => setState(() => _projectId = null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: on ? AppColors.accent : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    on ? Colors.transparent : AppColors.line),
                          ),
                          child: Text('No Project',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? AppColors.accentInk
                                      : AppColors.tx2)),
                        ),
                      );
                    }
                    final p = linkableProjects[i - 1];
                    final on = _projectId == p.id;
                    return GestureDetector(
                      onTap: () => setState(() => _projectId = p.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: on ? AppColors.accent : AppColors.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: on ? Colors.transparent : AppColors.line),
                        ),
                        child: Text(p.title,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: on
                                    ? AppColors.accentInk
                                    : AppColors.tx2)),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                for (final p in ['P1', 'P2', 'P3'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _priority == p
                              ? AppColors.surface4
                              : AppColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(p,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _priority == p
                                    ? AppColors.tx
                                    : AppColors.tx3)),
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton(
                    onPressed: () => setState(() {
                          _adding = false;
                          _title.clear();
                          _areaId = null;
                          _goalId = null;
                          _projectId = null;
                        }),
                    child: Text('Cancel',
                        style: TextStyle(color: AppColors.tx3))),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => _save(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentInk,
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save(BuildContext context) {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    context.read<LifeCubit>().addTask(
          title: title,
          areaId: _areaId,
          goalId: _goalId,
          projectId: _projectId,
          priority: Priority.fromLabel(_priority),
        );
    setState(() {
      _adding = false;
      _title.clear();
      _areaId = null;
      _goalId = null;
      _projectId = null;
    });
  }
}
