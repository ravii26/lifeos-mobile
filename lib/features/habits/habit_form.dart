import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/area.dart';
import '../../data/models/habit.dart';
import '../../widgets/form_kit.dart';
import '../shell/life_cubit.dart';

class HabitForm extends StatefulWidget {
  final Habit? habit;
  final List<Area> areas;
  const HabitForm({super.key, this.habit, required this.areas});

  @override
  State<HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<HabitForm> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  String? _areaId;
  String _type = 'BOOLEAN';
  String _frequency = 'DAILY';
  TimeOfDay? _reminder;
  bool _saving = false;

  bool get _isEdit => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _title = TextEditingController(text: h?.title ?? '');
    _type = h?.habitType ?? 'BOOLEAN';
    _frequency = h?.frequency ?? 'DAILY';
    _areaId = h?.areaId ??
        (widget.areas.isNotEmpty ? widget.areas.first.id : null);
    final t = _type == 'TIMER' ? (h?.targetMinutes ?? 0) : (h?.targetCount ?? 0);
    _target = TextEditingController(text: t > 0 ? '$t' : '');
    _reminder = _parseTime(h?.reminderTime);
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null || !s.contains(':')) return null;
    final parts = s.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _fmtReminder() => _reminder == null
      ? null
      : '${_reminder!.hour.toString().padLeft(2, '0')}:${_reminder!.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (title.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Give the habit a title first.')));
      return;
    }
    if (_areaId == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Create an area first — habits live inside an area.')));
      return;
    }
    setState(() => _saving = true);
    final n = int.tryParse(_target.text.trim());
    final ok = await context.read<LifeCubit>().saveHabit(
          id: widget.habit?.id,
          title: title,
          areaId: _areaId!,
          habitType: _type,
          targetCount: _type == 'COUNT' ? (n ?? 1) : null,
          targetMinutes: _type == 'TIMER' ? (n ?? 10) : null,
          frequency: _frequency,
          reminderTime: _fmtReminder(),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      // Save failed (error surfaced globally); keep the sheet open so the
      // user doesn't lose their input.
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit ? 'Edit this habit' : 'A new habit',
      children: [
        formField(_title, 'Like a walk after dinner', autofocus: !_isEdit),
        const SizedBox(height: 16),
        formLabel('Part of life'),
        chipWrap([
          for (final a in widget.areas)
            selChip(a.name, _areaId == a.id,
                () => setState(() => _areaId = a.id),
                color: a.color),
        ]),
        const SizedBox(height: 16),
        formLabel('How do you want to track it?'),
        chipWrap([
          for (final t in const ['BOOLEAN', 'COUNT', 'TIMER'])
            selChip(_typeLabel(t), _type == t, () => setState(() => _type = t)),
        ]),
        if (_type != 'BOOLEAN') ...[
          const SizedBox(height: 14),
          formLabel(_type == 'TIMER' ? 'Minutes a day' : 'How many a day'),
          formField(_target, _type == 'TIMER' ? 'e.g. 30' : 'e.g. 8',
              keyboard: TextInputType.number),
        ],
        const SizedBox(height: 16),
        formLabel('How often?'),
        chipWrap([
          for (final f in const ['DAILY', 'WEEKLY'])
            selChip(titleCaseWord(f), _frequency == f,
                () => setState(() => _frequency = f)),
        ]),
        const SizedBox(height: 16),
        formLabel('Reminder'),
        Row(
          children: [
            formPick(Icons.alarm, _reminder == null ? 'Pick a time' : _reminder!.format(context), () async {
              final picked = await showTimePicker(
                  context: context,
                  initialTime: _reminder ?? const TimeOfDay(hour: 8, minute: 0));
              if (picked != null) setState(() => _reminder = picked);
            }),
            if (_reminder != null) formClear(() => setState(() => _reminder = null)),
          ],
        ),
        const SizedBox(height: 22),
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Add it'),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete this habit', () async {
            if (await confirmDelete(
                context, '“${widget.habit!.title}” will be removed.')) {
              if (!context.mounted) return;
              context.read<LifeCubit>().deleteHabit(widget.habit!.id);
              Navigator.of(context).pop();
            }
          }),
        ],
      ],
    );
  }

  static String _typeLabel(String t) => switch (t) {
        'COUNT' => 'Count',
        'TIMER' => 'Minutes',
        _ => 'Done or not',
      };
}
