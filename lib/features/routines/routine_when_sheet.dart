import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'routine_words.dart';

/// When a routine happens: how often, which days, and which part of the day.
class RoutineWhen {
  final String frequency; // DAILY | CUSTOM | WEEKLY
  final List<String> days; // for CUSTOM
  final int timesAWeek; // for WEEKLY
  final String? part; // null = anytime

  const RoutineWhen({this.frequency = 'DAILY', this.days = const [], this.timesAWeek = 3, this.part});

  bool get valid => frequency != 'CUSTOM' || days.isNotEmpty;
  String get words => whenWords(frequency: frequency, days: days, weeklyTarget: timesAWeek) + (part == null ? '' : ' · ${partLabel(part).toLowerCase()}');

  RoutineWhen copyWith({String? frequency, List<String>? days, int? timesAWeek, String? part, bool anytime = false}) => RoutineWhen(
        frequency: frequency ?? this.frequency,
        days: days ?? this.days,
        timesAWeek: timesAWeek ?? this.timesAWeek,
        part: anytime ? null : (part ?? this.part),
      );
}

/// The "when" controls, used by the new-routine form and the change sheet.
class RoutineWhenEditor extends StatelessWidget {
  final RoutineWhen value;
  final ValueChanged<RoutineWhen> onChanged;
  const RoutineWhenEditor({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('HOW OFTEN', style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x2),
      AllySegmented<String>(
        options: const {'DAILY': 'Every day', 'CUSTOM': 'Some days', 'WEEKLY': 'A few times'},
        value: value.frequency,
        onChanged: (f) => onChanged(value.copyWith(frequency: f)),
      ),
      const SizedBox(height: Sp.x3),
      if (value.frequency == 'CUSTOM')
        Wrap(spacing: Sp.x1, runSpacing: Sp.x1, children: [
          for (var i = 0; i < 7; i++)
            AllyChip(
              weekdayShort[i],
              selected: value.days.contains(weekdayCodes[i]),
              onTap: () {
                final d = weekdayCodes[i];
                final next = value.days.contains(d) ? (value.days.where((x) => x != d).toList()) : [...value.days, d];
                onChanged(value.copyWith(days: next));
              },
            ),
        ]),
      if (value.frequency == 'WEEKLY')
        Row(children: [
          Expanded(child: Text(whenWords(frequency: 'WEEKLY', weeklyTarget: value.timesAWeek), style: AllyType.body(color: c.ink))),
          _round(c, Icons.remove_rounded, 'Fewer', value.timesAWeek <= 1 ? null : () => onChanged(value.copyWith(timesAWeek: value.timesAWeek - 1))),
          const SizedBox(width: Sp.x2),
          _round(c, Icons.add_rounded, 'More', value.timesAWeek >= 6 ? null : () => onChanged(value.copyWith(timesAWeek: value.timesAWeek + 1))),
        ]),
      const SizedBox(height: Sp.x4),
      Text('PART OF THE DAY', style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x2),
      Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
        for (final (block, label) in dayParts)
          AllyChip(label,
              selected: value.part == block,
              onTap: () => onChanged(block == null ? value.copyWith(anytime: true) : value.copyWith(part: block))),
      ]),
    ]);
  }

  Widget _round(AllyColors c, IconData icon, String label, VoidCallback? onTap) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Pressable(
          onTap: onTap,
          scale: 0.92,
          semanticLabel: label,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Rad.chip), border: Border.all(color: c.line)),
            child: Icon(icon, color: c.ink, size: 22),
          ),
        ),
      );
}

/// Change when an existing routine happens. Pops with the new [RoutineWhen], or null.
class RoutineWhenSheet extends StatefulWidget {
  final RoutineWhen initial;
  const RoutineWhenSheet({super.key, required this.initial});

  @override
  State<RoutineWhenSheet> createState() => _RoutineWhenSheetState();
}

class _RoutineWhenSheetState extends State<RoutineWhenSheet> {
  late RoutineWhen _v = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('When it happens', style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x4),
      RoutineWhenEditor(value: _v, onChanged: (v) => setState(() => _v = v)),
      const SizedBox(height: Sp.x5),
      AllyButton(_v.valid ? 'Save: ${_v.words}' : 'Pick at least one day',
          wide: true, onPressed: _v.valid ? () => Navigator.of(context).pop<RoutineWhen>(_v) : null),
    ]);
  }
}
