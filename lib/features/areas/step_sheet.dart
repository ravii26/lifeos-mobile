import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../today/day_shape.dart' show duration;
import 'areas_overview.dart';

/// What the step sheet asks for. Exactly one kind per answer.
sealed class StepAnswer {
  const StepAnswer();
}

class StepSave extends StepAnswer {
  final String title;

  /// Null = no length set.
  final int? minutes;

  /// LOW | NORMAL | HIGH.
  final String energy;

  /// Empty = no smaller version.
  final String smaller;
  const StepSave(this.title, this.minutes, this.energy, this.smaller);
}

class StepMove extends StepAnswer {
  /// TOMORROW | WEEKEND | NEXT_WEEK.
  final String when;
  const StepMove(this.when);
}

class StepLetGo extends StepAnswer {
  const StepLetGo();
}

/// Add a step, or change one: name, length, the energy it takes, a smaller
/// version for hard days; and for an existing step, move it or let it go.
/// Pops with a [StepAnswer], or null when closed.
class StepSheet extends StatefulWidget {
  /// Null to add a new step.
  final AreaStep? step;
  final String areaName;

  const StepSheet({super.key, this.step, required this.areaName});

  @override
  State<StepSheet> createState() => _StepSheetState();
}

class _StepSheetState extends State<StepSheet> {
  static const _lengths = [5, 10, 15, 25, 30, 45, 60, 90];

  late final _title = TextEditingController(text: widget.step?.title ?? '');
  late final _smaller = TextEditingController(text: widget.step?.smaller ?? '');
  late int? _minutes = widget.step?.minutes;
  late String _energy = widget.step?.energy ?? 'NORMAL';

  bool get _adding => widget.step == null;
  bool get _named => _title.text.trim().isNotEmpty;

  // A length set elsewhere (by chat, say) stays offered even if it isn't a usual one.
  List<int> get _choices {
    final m = widget.step?.minutes;
    return m == null || _lengths.contains(m) ? _lengths : ([..._lengths, m]..sort());
  }

  @override
  void dispose() {
    _title.dispose();
    _smaller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop<StepAnswer>(StepSave(_title.text.trim(), _minutes, _energy, _smaller.text.trim()));

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_adding ? 'New step' : 'Edit step', style: AllyType.h2(color: c.ink)),
        Text(widget.areaName, style: AllyType.small(color: c.faint)),
        const SizedBox(height: Sp.x3),
        TextField(
          controller: _title,
          autofocus: _adding,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          style: AllyType.body(color: c.ink),
          decoration: const InputDecoration(hintText: 'What to do', counterText: ''),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Sp.x4),
        Text('HOW LONG', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final m in _choices)
            AllyChip(duration(m), selected: _minutes == m, onTap: () => setState(() => _minutes = _minutes == m ? null : m)),
        ]),
        const SizedBox(height: Sp.x4),
        Text('ENERGY IT TAKES', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        AllySegmented<String>(
          options: const {'LOW': 'Light', 'NORMAL': 'Normal', 'HIGH': 'Demanding'},
          value: _energy,
          onChanged: (v) => setState(() => _energy = v),
        ),
        const SizedBox(height: Sp.x1),
        Text(
          switch (_energy) {
            'LOW' => 'Fine on a tired evening.',
            'HIGH' => 'Kept for good-energy times. On a low day only its smaller version is offered.',
            _ => 'Most things.',
          },
          style: AllyType.small(color: c.faint),
        ),
        const SizedBox(height: Sp.x4),
        Text('SMALLER VERSION', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        TextField(
          controller: _smaller,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          style: AllyType.body(color: c.ink),
          decoration: const InputDecoration(hintText: 'For a hard day, e.g. "just open the file"', counterText: ''),
        ),
        const SizedBox(height: Sp.x4),
        AllyButton(_adding ? 'Add step' : 'Save', wide: true, onPressed: _named ? _save : null),
        if (!_adding) ...[
          const SizedBox(height: Sp.x5),
          Text('MOVE IT', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final (label, to) in const [('Tomorrow', 'TOMORROW'), ('This weekend', 'WEEKEND'), ('Next week', 'NEXT_WEEK')])
              AllyChip(label, onTap: () => Navigator.of(context).pop<StepAnswer>(StepMove(to))),
          ]),
          const SizedBox(height: Sp.x3),
          AllyButton('Let this go',
              kind: AllyButtonKind.ghost,
              wide: true,
              onPressed: () => Navigator.of(context).pop<StepAnswer>(const StepLetGo())),
        ],
      ],
    );
  }
}
