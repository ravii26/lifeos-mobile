import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/task.dart';
import '../../widgets/form_kit.dart' show chipWrap, gFieldStyle, selChip;
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
        final today = s.openTasks
            .where((t) => t.dueDate != null && DateUtils.isSameDay(t.dueDate, DateTime.now()))
            .length;
        final later = s.openTasks.length - today;

        return Scaffold(
          backgroundColor: G.bg,
          appBar: gBar(actions: [
            IconButton(
              tooltip: 'Add a to-do',
              icon: Icon(_adding ? Icons.close_rounded : Icons.add_rounded, size: 28, color: G.accent),
              onPressed: () => setState(() => _adding = !_adding),
            ),
          ]),
          body: RefreshIndicator(
            color: G.accent,
            backgroundColor: G.card,
            onRefresh: () => context.read<LifeCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              children: [
                GTitle('All to-dos', sub: '$today for today, $later for later.'),
                _lanes(),
                const SizedBox(height: 14),
                if (_adding) _addCard(context),
                if (list.isEmpty)
                  GEmpty(_lane == 'done'
                      ? 'Finished to-dos will show up here.'
                      : _lane == 'backlog'
                          ? 'Nothing waiting for later.'
                          : 'Nothing set for today.')
                else ...[
                  for (final t in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                          onComplete: () => context.read<LifeCubit>().completeTask(t.id),
                          onDelete: () => context.read<LifeCubit>().deleteTask(t.id),
                        ),
                      ),
                    ),
                  if (_lane != 'done')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Swipe right when done, left to remove.', textAlign: TextAlign.center, style: G.text(15, color: G.muted, height: 1.3)),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lanes() {
    Widget lane(String id, String label) {
      final on = _lane == id;
      return Expanded(
        child: Material(
          color: on ? G.accent : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _lane = id),
            child: SizedBox(
              height: 46,
              child: Center(
                child: Text(label, style: G.text(16, w: on ? FontWeight.w600 : FontWeight.w400, color: on ? G.onInk : G.ink, height: 1.2)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(27)),
      child: Row(children: [
        lane('today', 'Today'),
        lane('backlog', 'Later'),
        lane('done', 'Done'),
      ]),
    );
  }

  Widget _addCard(BuildContext context) {
    return GCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            cursorColor: G.accent,
            style: G.text(18, height: 1.3),
            decoration: gFieldStyle('What needs doing?', fill: G.surfaceHigh),
          ),
          const SizedBox(height: 12),
          chipWrap([
            for (final p in const [('P1', 'High'), ('P2', 'Normal'), ('P3', 'Low')])
              selChip(p.$2, _priority == p.$1, () => setState(() => _priority = p.$1)),
          ]),
          const SizedBox(height: 14),
          GPill('Add it', primary: true, onTap: () => _save(context)),
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
