import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../data/models/calendar_block.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart';

const _blockTypes = ['FOCUS', 'ADMIN', 'BREAK', 'MEETING', 'PERSONAL'];

/// What an edit applies to when the block is part of a recurring series.
enum EditScope {
  /// A standalone block, or creating a new one.
  single,

  /// Just this one occurrence (writes a per-occurrence override).
  occurrence,

  /// This occurrence and every later one (splits the series).
  following,

  /// The whole series template.
  series,
}

// ---- RRULE <-> preset mapping --------------------------------------------
const _kWeekdays = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';

String _ruleFor(String preset, String custom) => switch (preset) {
      'Daily' => 'FREQ=DAILY',
      'Weekdays' => _kWeekdays,
      'Weekly' => 'FREQ=WEEKLY',
      'Custom' => custom.trim(),
      _ => '',
    };

String _presetFor(String? rule) {
  final r = (rule ?? '').trim().toUpperCase();
  if (r.isEmpty) return 'None';
  if (r == 'FREQ=DAILY') return 'Daily';
  if (r == _kWeekdays) return 'Weekdays';
  if (r == 'FREQ=WEEKLY') return 'Weekly';
  return 'Custom';
}

class BlockForm extends StatefulWidget {
  final CalendarBlock? block;
  final List<Area> areas;
  final DateTime day;
  final EditScope scope;
  const BlockForm({
    super.key,
    this.block,
    required this.areas,
    required this.day,
    this.scope = EditScope.single,
  });

  @override
  State<BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends State<BlockForm> {
  late final TextEditingController _title;
  late final TextEditingController _customRule;
  String? _areaId;
  String _blockType = 'FOCUS';
  String _recurrence = 'None';
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;

  bool get _isEdit => widget.block != null;
  EditScope get _scope => widget.scope;

  /// The recurrence picker is meaningless when editing a single occurrence.
  bool get _showRecurrence => _scope != EditScope.occurrence;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    _title = TextEditingController(text: b?.title ?? '');
    _blockType = b?.blockType ?? 'FOCUS';
    _areaId = b?.areaId;
    _start = b != null
        ? TimeOfDay(hour: b.startTime.hour, minute: b.startTime.minute)
        : const TimeOfDay(hour: 9, minute: 0);
    _end = b != null
        ? TimeOfDay(hour: b.endTime.hour, minute: b.endTime.minute)
        : const TimeOfDay(hour: 10, minute: 0);
    _recurrence = _presetFor(b?.recurrenceRule);
    _customRule = TextEditingController(
        text: _recurrence == 'Custom' ? (b?.recurrenceRule ?? '') : '');
  }

  @override
  void dispose() {
    _title.dispose();
    _customRule.dispose();
    super.dispose();
  }

  /// The occurrence's date stays fixed; only the time-of-day is edited.
  DateTime _at(TimeOfDay t, {DateTime? on}) {
    final d = on ?? widget.day;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  String get _title2 => switch (_scope) {
        EditScope.occurrence => 'Edit this occurrence',
        EditScope.following => 'Edit this & following',
        EditScope.series => 'Edit series',
        EditScope.single => _isEdit ? 'Edit block' : 'New time block',
      };

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    // Occurrence overrides keep the occurrence's own date; series/single use the day.
    final baseDate = _scope == EditScope.single || !_isEdit
        ? widget.day
        : (widget.block!.occurrenceDate ?? widget.block!.startTime);
    final start = _at(_start, on: baseDate);
    final end = _at(_end, on: baseDate);
    if (!end.isAfter(start)) {
      _toast('End time must be after start.');
      return;
    }
    final rule = _ruleFor(_recurrence, _customRule.text);

    setState(() => _saving = true);
    final repo = getIt<LifeRepository>();
    try {
      final b = widget.block;
      switch (_scope) {
        case EditScope.single:
          if (_isEdit) {
            await repo.updateBlock(b!.id,
                title: title,
                startTime: start,
                endTime: end,
                blockType: _blockType,
                areaId: _areaId,
                recurrenceRule: rule);
          } else {
            await repo.createBlock(
                title: title,
                startTime: start,
                endTime: end,
                blockType: _blockType,
                areaId: _areaId,
                recurrenceRule: rule);
          }
        case EditScope.occurrence:
          await repo.upsertException(b!.seriesId,
              occurrenceDate: b.occurrenceDate!,
              title: title,
              startTime: start,
              endTime: end,
              blockType: _blockType);
        case EditScope.series:
          await repo.updateBlock(b!.seriesId,
              title: title,
              startTime: start,
              endTime: end,
              blockType: _blockType,
              areaId: _areaId,
              recurrenceRule: rule);
        case EditScope.following:
          await repo.splitSeries(b!.seriesId,
              fromOccurrenceDate: b.occurrenceDate!,
              title: title,
              startTime: start,
              endTime: end,
              blockType: _blockType,
              areaId: _areaId,
              recurrenceRule: rule.isEmpty ? null : rule);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
        context: context, initialTime: isStart ? _start : _end);
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _title2,
      children: [
        formField(_title, 'What are you doing?', autofocus: !_isEdit),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _timeBtn('Start', _start, () => _pick(true))),
            const SizedBox(width: 12),
            Expanded(child: _timeBtn('End', _end, () => _pick(false))),
          ],
        ),
        const SizedBox(height: 16),
        formLabel('Type'),
        chipWrap([
          for (final t in _blockTypes)
            selChip(titleCaseWord(t), _blockType == t,
                () => setState(() => _blockType = t)),
        ]),
        if (_scope != EditScope.occurrence && widget.areas.isNotEmpty) ...[
          const SizedBox(height: 16),
          formLabel('Area (optional)'),
          chipWrap([
            selChip('None', _areaId == null,
                () => setState(() => _areaId = null)),
            for (final a in widget.areas)
              selChip(a.name, _areaId == a.id,
                  () => setState(() => _areaId = a.id),
                  color: a.color),
          ]),
        ],
        if (_showRecurrence) ...[
          const SizedBox(height: 16),
          formLabel('Repeat'),
          chipWrap([
            for (final r in const [
              'None',
              'Daily',
              'Weekdays',
              'Weekly',
              'Custom'
            ])
              selChip(r, _recurrence == r,
                  () => setState(() => _recurrence = r)),
          ]),
          if (_recurrence == 'Custom') ...[
            const SizedBox(height: 10),
            formField(_customRule, 'RRULE e.g. FREQ=WEEKLY;BYDAY=MO,WE,FR'),
          ],
        ],
        const SizedBox(height: 22),
        saveButton(_saving, _save, _isEdit ? 'Save changes' : 'Add block'),
        if (_isEdit && _scope == EditScope.occurrence) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: _resetOccurrence,
              icon: Icon(Icons.restore, size: 18, color: AppColors.tx3),
              label: Text('Reset to series default',
                  style: TextStyle(color: AppColors.tx3)),
            ),
          ),
        ],
        if (_isEdit && _scope == EditScope.single) ...[
          const SizedBox(height: 6),
          deleteRow(context, 'Delete block', () async {
            if (await confirmDelete(
                context, '“${widget.block!.title}” will be removed.')) {
              await getIt<LifeRepository>().deleteBlock(widget.block!.id);
              if (context.mounted) Navigator.of(context).pop(true);
            }
          }),
        ],
      ],
    );
  }

  Future<void> _resetOccurrence() async {
    final b = widget.block!;
    try {
      await getIt<LifeRepository>()
          .deleteException(b.seriesId, b.occurrenceDate!);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Widget _timeBtn(String label, TimeOfDay t, VoidCallback onTap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel(label),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.schedule, size: 16),
            label: Text(t.format(context)),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.tx,
                side: BorderSide(color: AppColors.line2),
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 14)),
          ),
        ],
      );
}
