import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/area.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../shell/life_cubit.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_row.dart';
import 'areas_screen.dart' show openAreaForm;

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
            appBar: const GTopBar('Area', showBack: true),
            body: Center(
              child: Text('Area not found', style: G.voice(15, color: G.muted)),
            ),
          );
        }
        final area = a;
        final tasks =
            s.openTasks.where((t) => t.areaId == area.id).toList();
        final habits =
            s.habits.where((h) => h.areaId == area.id).toList();

        return Scaffold(
          backgroundColor: G.bg,
          appBar: GTopBar(
            area.name,
            subtitle: area.type == 'PRIMARY' ? 'Primary focus' : 'Maintenance',
            showBack: true,
            trailing: IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: G.muted),
              onPressed: () => openAreaForm(context, area: area),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: area.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Area Balance',
                              style: G.label(size: 11, color: G.faint),
                            ),
                          ],
                        ),
                        Text(
                          '${area.score}%',
                          style: G.numeral(24, color: G.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('${area.tasksDone}/${area.tasksTotal} tasks done',
                            style: G.label(size: 11, color: G.muted)),
                        Text(' · ', style: G.label(size: 11, color: G.faint)),
                        Text('${area.streak}d streak',
                            style: G.label(size: 11, color: G.muted)),
                        Text(' · ', style: G.label(size: 11, color: G.faint)),
                        Text('${area.focusMins}m focus',
                            style: G.label(size: 11, color: G.muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: G.inset,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (area.score / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: area.color,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Text('OPEN TASKS (${tasks.length})',
                    style: G.label(size: 11, color: G.faint)),
              ),
              if (tasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: G.card,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text('No open tasks in this area.',
                        style: G.voice(13.5, color: G.muted)),
                  ),
                )
              else
                for (final t in tasks)
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Text('HABITS (${habits.length})',
                    style: G.label(size: 11, color: G.faint)),
              ),
              if (habits.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: G.card,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text('No habits in this area.',
                        style: G.voice(13.5, color: G.muted)),
                  ),
                )
              else
                for (final h in habits)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: G.card,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: G.lineSoft, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: area.color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            h.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: G.text(14,
                                w: FontWeight.w400, color: G.ink),
                          ),
                        ),
                        Text(
                          '${h.currentStreak}d continuity',
                          style: G.label(size: 11, color: G.faint),
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
