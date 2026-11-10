import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/area.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../habits/habits_screen.dart' show habitWeekLine;
import '../shell/life_cubit.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_row.dart';
import 'areas_screen.dart' show areaLine, openAreaForm;

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
            backgroundColor: G.bg,
            appBar: gBar(),
            body: Center(
              child: Text("Couldn't find this.", style: G.text(18, color: G.muted, height: 1.35)),
            ),
          );
        }
        final area = a;
        final tasks = s.openTasks.where((t) => t.areaId == area.id).toList();
        final habits = s.habits.where((h) => h.areaId == area.id).toList();

        return Scaffold(
          backgroundColor: G.bg,
          appBar: gBar(actions: [
            IconButton(
              tooltip: 'Edit',
              icon: Icon(Icons.edit_outlined, size: 23, color: G.ink),
              onPressed: () => openAreaForm(context, area: area),
            ),
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            children: [
              GTitle(area.name, sub: areaLine(area.tasksDone, area.tasksTotal, area.focusMins)),
              const GHeading('To-dos'),
              if (tasks.isEmpty)
                const GEmpty('Nothing open here.')
              else
                for (final t in tasks)
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
                      child: TaskRow(
                        task: t,
                        area: area,
                        onComplete: () => context.read<LifeCubit>().completeTask(t.id),
                        onDelete: () => context.read<LifeCubit>().deleteTask(t.id),
                      ),
                    ),
                  ),
              const GHeading('Habits'),
              if (habits.isEmpty)
                const GEmpty('No habits here yet.')
              else
                for (final h in habits)
                  GCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.title, style: G.text(19, height: 1.3)),
                      const SizedBox(height: 2),
                      Text(habitWeekLine(h.history), style: G.text(16, color: G.muted, height: 1.3)),
                    ]),
                  ),
            ],
          ),
        );
      },
    );
  }
}
