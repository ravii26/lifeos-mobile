import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../data/models/task.dart';
import '../../widgets/form_kit.dart';
import '../shell/life_cubit.dart';

/// Edit an existing task — title, priority, area, due date, status.
/// Creating is still done via the inline add-card on the Tasks screen.
class TaskForm extends StatefulWidget {
  final Task task;
  final List<Area> areas;
  const TaskForm({super.key, required this.task, required this.areas});

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  late final TextEditingController _title;
  String? _areaId;
  late String _priority; // P1/P2/P3 label
  late String _status; // TODO | IN_PROGRESS | COMPLETED | CANCELLED
  DateTime? _due;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t.title);
    _areaId = t.areaId;
    _priority = t.priorityLabel;
    _status = t.status.toUpperCase();
    _due = t.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (title.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Give the task a title first.')));
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<LifeCubit>().editTask(
          widget.task.id,
          title: title,
          priority: Priority.fromLabel(_priority),
          status: _status,
          areaId: _areaId,
          dueDate: _due,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Edit task',
      children: [
        formField(_title, 'Task title'),
        const SizedBox(height: 16),
        formLabel('Priority'),
        chipWrap([
          for (final p in const ['P1', 'P2', 'P3'])
            selChip(p, _priority == p, () => setState(() => _priority = p)),
        ]),
        const SizedBox(height: 16),
        formLabel('Status'),
        chipWrap([
          for (final s in const ['TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'])
            selChip(_statusLabel(s), _status == s,
                () => setState(() => _status = s)),
        ]),
        if (widget.areas.isNotEmpty) ...[
          const SizedBox(height: 16),
          formLabel('Area'),
          chipWrap([
            selChip('None', _areaId == null,
                () => setState(() => _areaId = null)),
            for (final a in widget.areas)
              selChip(a.name, _areaId == a.id,
                  () => setState(() => _areaId = a.id),
                  color: a.color),
          ]),
        ],
        const SizedBox(height: 16),
        formLabel('Due date'),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 5),
                );
                if (picked != null) setState(() => _due = picked);
              },
              icon: const Icon(Icons.event, size: 16),
              label: Text(_due == null ? 'Set due date' : _fmtDate(_due!)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tx2,
                  side: BorderSide(color: AppColors.line2)),
            ),
            if (_due != null)
              TextButton(
                  onPressed: () => setState(() => _due = null),
                  child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 22),
        saveButton(_saving, _save, 'Save changes'),
        const SizedBox(height: 6),
        deleteRow(context, 'Delete task', () async {
          if (await confirmDelete(
              context, '“${widget.task.title}” will be removed.')) {
            if (!context.mounted) return;
            context.read<LifeCubit>().deleteTask(widget.task.id);
            Navigator.of(context).pop();
          }
        }),
      ],
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'TODO' => 'To do',
        'IN_PROGRESS' => 'In progress',
        'COMPLETED' => 'Done',
        'CANCELLED' => 'Cancelled',
        _ => s,
      };

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
