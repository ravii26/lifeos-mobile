import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/task.dart';
import '../guide/guide_style.dart';
import '../shell/life_cubit.dart';
import 'task_detail_screen.dart';
import 'task_form.dart';
import 'task_row.dart';

class TasksScreen extends StatefulWidget {
  final VoidCallback? onOpenMore;
  const TasksScreen({super.key, this.onOpenMore});

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

        return Scaffold(
          backgroundColor: G.bg,
          appBar: GTopBar(
            'Tasks',
            subtitle:
                '${counts['today']} due today · ${counts['backlog']} open',
            showBack: true,
            trailing: IconButton(
              icon: Icon(Icons.add, size: 20, color: G.accent),
              onPressed: () => setState(() => _adding = !_adding),
            ),
          ),
          body: RefreshIndicator(
            color: G.accent,
            backgroundColor: G.card,
            onRefresh: () => context.read<LifeCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                _segmented(counts),
                const SizedBox(height: 14),
                if (_adding) _addTaskCard(context, s),
                const SizedBox(height: 6),
                if (list.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _lane == 'done'
                            ? 'Complete a task to see it here.'
                            : _lane == 'backlog'
                                ? 'Backlog is empty. Clear minds rest better.'
                                : 'Nothing scheduled for today.',
                        textAlign: TextAlign.center,
                        style: G.voice(14, color: G.muted),
                      ),
                    ),
                  )
                else
                  for (final t in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
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
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Swipe right to complete · left to remove',
                    style: G.label(size: 10.5, color: G.faint),
                  ),
                ),
              ],
            ),
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: on ? G.accent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Text(
                '$label (${counts[id]})',
                style: G.text(
                  12.5,
                  w: on ? FontWeight.w600 : FontWeight.w400,
                  color: on ? G.accent : G.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: G.inset,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: G.lineSoft, width: 0.5),
      ),
      child: Row(children: [
        seg('today', 'Today'),
        seg('backlog', 'Backlog'),
        seg('done', 'Done'),
      ]),
    );
  }

  Widget _addTaskCard(BuildContext context, LifeState s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: G.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: G.lineSoft, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            style: G.text(14.5, color: G.ink),
            decoration: InputDecoration(
              hintText: 'What needs doing?',
              hintStyle: G.text(14, color: G.faint),
              filled: true,
              fillColor: G.inset,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: G.lineSoft, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: G.lineSoft, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: G.accent, width: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in ['P1', 'P2', 'P3'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _priority == p
                            ? G.accent.withValues(alpha: 0.15)
                            : G.inset,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: _priority == p ? G.accent : G.lineSoft,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        p,
                        style: G.text(
                          12,
                          w: _priority == p ? FontWeight.w600 : FontWeight.w400,
                          color: _priority == p ? G.accent : G.muted,
                        ),
                      ),
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
                child: Text('Cancel', style: G.label(size: 12, color: G.faint)),
              ),
              const SizedBox(width: 4),
              OutlinedButton(
                onPressed: () => _save(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: G.accent.withValues(alpha: 0.12),
                  side: BorderSide(
                      color: G.accent.withValues(alpha: 0.4), width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text('Add',
                    style: G.text(13,
                        w: FontWeight.w600, color: G.accent)),
              ),
            ],
          ),
        ],
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
