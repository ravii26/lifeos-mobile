import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'areas_overview.dart';

/// "72,4" and "72.4" are both 72.4.
double? parseNumber(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

final _numeric = [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))];
const _keyboard = TextInputType.numberWithOptions(decimal: true, signed: true);

/// Start tracking a number: what, its unit, where it is now, where you want it.
/// Pops with those, or null.
class TrackNumberSheet extends StatefulWidget {
  final String areaName;
  const TrackNumberSheet({super.key, required this.areaName});

  @override
  State<TrackNumberSheet> createState() => _TrackNumberSheetState();
}

typedef NewNumberDraft = ({String name, String unit, double start, double target});

class _TrackNumberSheetState extends State<TrackNumberSheet> {
  final _name = TextEditingController();
  final _unit = TextEditingController();
  final _start = TextEditingController();
  final _target = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _unit, _start, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _problem {
    final s = parseNumber(_start.text), t = parseNumber(_target.text);
    if (_name.text.trim().isEmpty || s == null || t == null) return null;
    if (s == t) return 'The goal is where it already is. Pick a different target.';
    return null;
  }

  bool get _ready {
    final s = parseNumber(_start.text), t = parseNumber(_target.text);
    return _name.text.trim().isNotEmpty && s != null && t != null && s != t;
  }

  Widget _field(AllyColors c, TextEditingController ctl, String label, String hint, {bool number = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          TextField(
            controller: ctl,
            keyboardType: number ? _keyboard : TextInputType.text,
            inputFormatters: number ? _numeric : null,
            textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
            maxLength: number ? 12 : 60,
            style: AllyType.body(color: c.ink),
            decoration: InputDecoration(hintText: hint, counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Track a number', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('One number that shows ${widget.areaName} moving. Add a reading whenever you check it.',
            style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x4),
        _field(c, _name, 'WHAT', 'For example: Weight, Savings, Pages read'),
        const SizedBox(height: Sp.x3),
        _field(c, _unit, 'UNIT (OPTIONAL)', 'kg, ₹, pages'),
        const SizedBox(height: Sp.x3),
        Row(children: [
          Expanded(child: _field(c, _start, 'NOW', '0', number: true)),
          const SizedBox(width: Sp.x3),
          Expanded(child: _field(c, _target, 'GOAL', '0', number: true)),
        ]),
        if (_problem != null) ...[
          const SizedBox(height: Sp.x2),
          Text(_problem!, style: AllyType.small(color: c.warn)),
        ],
        const SizedBox(height: Sp.x4),
        AllyButton('Start tracking',
            wide: true,
            onPressed: _ready
                ? () => Navigator.of(context).pop<NewNumberDraft>((
                      name: _name.text.trim(),
                      unit: _unit.text.trim(),
                      start: parseNumber(_start.text)!,
                      target: parseNumber(_target.text)!,
                    ))
                : null),
      ],
    );
  }
}

/// One new reading for a tracked number. Pops with the value, or null.
class ReadingSheet extends StatefulWidget {
  final TrackedNumber number;
  const ReadingSheet({super.key, required this.number});

  @override
  State<ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends State<ReadingSheet> {
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final n = widget.number;
    final v = parseNumber(_value.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(n.name, style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('Last: ${TrackedNumber.show(n.latest)}${n.unit.isEmpty ? '' : ' ${n.unit}'}', style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x3),
        TextField(
          controller: _value,
          autofocus: true,
          keyboardType: _keyboard,
          inputFormatters: _numeric,
          maxLength: 12,
          style: AllyType.h2(color: c.ink),
          decoration: InputDecoration(hintText: 'Today', counterText: '', suffixText: n.unit.isEmpty ? null : n.unit),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (v != null) Navigator.of(context).pop<double>(v);
          },
        ),
        const SizedBox(height: Sp.x4),
        AllyButton('Save reading', wide: true, onPressed: v == null ? null : () => Navigator.of(context).pop<double>(v)),
      ],
    );
  }
}
