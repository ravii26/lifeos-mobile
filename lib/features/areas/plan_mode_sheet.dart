import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'areas_overview.dart';

/// "1 Dec" from "2026-12-01".
String shortDay(String key) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = DateTime.tryParse(key);
  return d == null ? key : '${d.day} ${months[d.month - 1]}';
}

/// Plan a mode change for later: "after the exam, Study goes to Maintain".
/// Pops with the mode and the day, or null.
class PlanModeSheet extends StatefulWidget {
  final String areaName;
  final AreaMode current;

  /// For tests.
  final DateTime Function()? clock;

  const PlanModeSheet({super.key, required this.areaName, required this.current, this.clock});

  @override
  State<PlanModeSheet> createState() => _PlanModeSheetState();
}

class _PlanModeSheetState extends State<PlanModeSheet> {
  late AreaMode _mode = AreaMode.values.firstWhere((m) => m != widget.current);
  DateTime? _day;

  DateTime get _today {
    final n = (widget.clock ?? DateTime.now)();
    return DateTime(n.year, n.month, n.day);
  }

  List<(String, DateTime)> get _quick => [
        ('In a week', _today.add(const Duration(days: 7))),
        ('In 2 weeks', _today.add(const Duration(days: 14))),
        ('In a month', DateTime(_today.year, _today.month + 1, _today.day)),
      ];

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      firstDate: _today.add(const Duration(days: 1)),
      lastDate: _today.add(const Duration(days: 730)),
      initialDate: _day ?? _today.add(const Duration(days: 7)),
    );
    if (d != null && mounted) setState(() => _day = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final quickKeys = _quick.map((q) => _key(q.$2)).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Plan a change', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('For when you know things will shift, like after a deadline or a move. It happens on that day by itself.',
            style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x4),
        Text('${widget.areaName.toUpperCase()} BECOMES', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        AllySegmented<AreaMode>(
          options: {for (final m in AreaMode.values.where((m) => m != widget.current)) m: m.label},
          value: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: Sp.x1),
        Text(_mode.meaning, style: AllyType.small(color: c.faint)),
        const SizedBox(height: Sp.x4),
        Text('FROM', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final (label, day) in _quick)
            AllyChip(label, selected: _day != null && _key(_day!) == _key(day), onTap: () => setState(() => _day = day)),
          AllyChip(
            _day != null && !quickKeys.contains(_key(_day!)) ? shortDay(_key(_day!)) : 'Pick a day',
            selected: _day != null && !quickKeys.contains(_key(_day!)),
            onTap: _pick,
          ),
        ]),
        const SizedBox(height: Sp.x5),
        AllyButton(
          _day == null ? 'Choose a day' : '${_mode.label} from ${shortDay(_key(_day!))}',
          wide: true,
          onPressed: _day == null ? null : () => Navigator.of(context).pop<(AreaMode, DateTime)>((_mode, _day!)),
        ),
      ],
    );
  }
}
