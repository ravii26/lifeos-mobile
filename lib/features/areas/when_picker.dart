import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'areas_overview.dart';

/// When a step happens. A day is "on" it (hidden until then) or "by" it (any
/// day until then); hours are a window it is only offered inside. All empty = anytime.
class StepWhen {
  /// ON | BY; null = no day.
  final String? kind;

  /// YYYY-MM-DD.
  final String? day;

  /// "HH:MM".
  final String? from;
  final String? to;

  const StepWhen({this.kind, this.day, this.from, this.to});
  static const anytime = StepWhen();

  factory StepWhen.of(AreaStep? s) =>
      s == null ? anytime : StepWhen(kind: s.dueKey == null ? null : (s.dueKind ?? 'BY'), day: s.dueKey, from: s.windowFrom, to: s.windowTo);

  bool get isAnytime => day == null && from == null;

  /// "Tomorrow", "By Fri 21 Nov", "Mornings 6 to 8", "Tomorrow, 6 to 8"; null for anytime.
  /// The same words the server uses for a saved step.
  String? words(DateTime now) {
    String hour(String hhmm) {
      final h = int.parse(hhmm.substring(0, 2)), m = hhmm.substring(3);
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return m == '00' ? '$h12' : '$h12:$m';
    }

    final hours = from != null && to != null ? '${hour(from!)} to ${hour(to!)}' : null;
    final d = day == null ? null : DateTime.tryParse(day!);
    if (d == null) {
      if (hours == null) return null;
      final h = int.parse(from!.substring(0, 2));
      final part = h < 4 ? 'Nights' : (h < 12 ? 'Mornings' : (h < 17 ? 'Afternoons' : (h < 21 ? 'Evenings' : 'Nights')));
      return '$part $hours';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final n = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final name = n <= 0 ? 'Today' : (n == 1 ? 'Tomorrow' : '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}');
    final base = kind == 'BY' ? (n <= 1 ? 'By ${name.toLowerCase()}' : 'By $name') : name;
    return hours == null ? base : '$base, $hours';
  }

  Map<String, dynamic> toJson() => {'dueKind': day == null ? null : kind, 'dueKey': day, 'windowFrom': from, 'windowTo': to};

  @override
  bool operator ==(Object other) => other is StepWhen && other.kind == kind && other.day == day && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(kind, day, from, to);
}

/// Choose when something happens: anytime, on a day or by a day, and the hours
/// of the day. Used wherever a step or to-do is edited, so it reads the same everywhere.
class WhenPicker extends StatefulWidget {
  final StepWhen initial;

  /// The choice so far, and whether it is complete (a day chosen when one is needed).
  final void Function(StepWhen when, bool complete) onChanged;

  /// For tests.
  final DateTime Function()? clock;

  const WhenPicker({super.key, required this.initial, required this.onChanged, this.clock});

  @override
  State<WhenPicker> createState() => _WhenPickerState();
}

class _WhenPickerState extends State<WhenPicker> {
  // When: ANY | ON | BY, the day for ON and BY, and the hours.
  late String _kind = widget.initial.day == null ? 'ANY' : (widget.initial.kind ?? 'BY');
  late String? _day = widget.initial.day;
  late String? _from = widget.initial.from;
  late String? _to = widget.initial.to;

  static const _parts = [('Morning', '06:00', '09:00'), ('Afternoon', '12:00', '16:00'), ('Evening', '18:00', '21:00'), ('Night', '21:00', '23:00')];

  DateTime get _today {
    final n = (widget.clock ?? DateTime.now)();
    return DateTime(n.year, n.month, n.day);
  }

  static String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Tomorrow, the coming Saturday, the coming Monday; "by" also offers today.
  List<(String, String)> get _days {
    final t = _today;
    final sat = t.add(Duration(days: (6 - t.weekday + 7) % 7 == 0 ? 7 : (6 - t.weekday + 7) % 7));
    final mon = t.add(Duration(days: (8 - t.weekday) % 7 == 0 ? 7 : (8 - t.weekday) % 7));
    final tomorrow = t.add(const Duration(days: 1));
    return [
      ('Today', _key(t)),
      ('Tomorrow', _key(tomorrow)),
      if (_key(sat) != _key(tomorrow)) ('This weekend', _key(sat)),
      if (_key(mon) != _key(tomorrow)) ('Next week', _key(mon)),
    ];
  }

  static String _dayWords(String key) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.tryParse(key);
    return d == null ? key : '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  /// "6", "6:30", "9" on a 12-hour clock: the part of the day is said beside it.
  static String _hour(String hhmm) {
    final h = int.parse(hhmm.substring(0, 2)), m = hhmm.substring(3);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return m == '00' ? '$h12' : '$h12:$m';
  }

  bool get _customHours => _from != null && !_parts.any((p) => p.$2 == _from && p.$3 == _to);

  StepWhen get _when =>
      StepWhen(kind: _kind == 'ANY' || _day == null ? null : _kind, day: _kind == 'ANY' ? null : _day, from: _to == null ? null : _from, to: _from == null ? null : _to);

  /// What the choice means, said plainly.
  String get _meaning {
    final hours = _from != null && _to != null ? 'between ${_hour(_from!)} and ${_hour(_to!)}' : null;
    final dayKnown = _kind != 'ANY' && _day != null;
    final day = !dayKnown
        ? null
        : _day == _key(_today)
            ? 'today'
            : _day == _key(_today.add(const Duration(days: 1)))
                ? 'tomorrow'
                : _dayWords(_day!);
    if (_kind != 'ANY' && _day == null) return 'Choose a day.';
    if (_kind == 'ON') {
      final gone = _day!.compareTo(_key(_today)) <= 0;
      return '${gone ? 'Offered today' : 'Kept out of the way until $day'}${hours == null ? '.' : ', and only $hours.'}';
    }
    if (_kind == 'BY') return 'Offered any day until $day, sooner as it gets close${hours == null ? '.' : ', and only $hours.'}';
    return hours == null ? 'Offered whenever you have time for it.' : 'Offered only $hours, on any day.';
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 730)),
      initialDate: DateTime.tryParse(_day ?? '') ?? _today.add(const Duration(days: 1)),
    );
    if (d != null && mounted) _set(() => _day = _key(d));
  }

  Future<void> _pickHours() async {
    TimeOfDay at(String? hhmm, int fallback) =>
        hhmm == null ? TimeOfDay(hour: fallback, minute: 0) : TimeOfDay(hour: int.parse(hhmm.substring(0, 2)), minute: int.parse(hhmm.substring(3)));
    String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final from = await showTimePicker(context: context, initialTime: at(_from, 6), helpText: 'From');
    if (from == null || !mounted) return;
    final to = await showTimePicker(context: context, initialTime: at(_to, (from.hour + 2) % 24), helpText: 'Until');
    if (to == null || !mounted || hhmm(to) == hhmm(from)) return;
    _set(() {
      _from = hhmm(from);
      _to = hhmm(to);
    });
  }

  void _set(VoidCallback change) {
    setState(change);
    widget.onChanged(_when, _kind == 'ANY' || _day != null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('WHEN', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        AllySegmented<String>(
          options: const {'ANY': 'Anytime', 'ON': 'On a day', 'BY': 'By a day'},
          value: _kind,
          onChanged: (v) => _set(() => _kind = v),
        ),
        if (_kind != 'ANY') ...[
          const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final (label, key) in _days) AllyChip(label, selected: _day == key, onTap: () => _set(() => _day = key)),
            AllyChip(
              _day != null && !_days.any((d) => d.$2 == _day) ? _dayWords(_day!) : 'Pick a day',
              selected: _day != null && !_days.any((d) => d.$2 == _day),
              onTap: _pickDay,
            ),
          ]),
        ],
        const SizedBox(height: Sp.x3),
        Text('Hours of the day', style: AllyType.small(color: c.muted)),
        const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          AllyChip('Any hour', selected: _from == null, onTap: () => _set(() => _from = _to = null)),
          for (final (label, from, to) in _parts)
            AllyChip(label,
                selected: _from == from && _to == to,
                onTap: () => _set(() {
                      _from = from;
                      _to = to;
                    })),
          AllyChip(_customHours ? '${_hour(_from!)} to ${_hour(_to!)}' : 'Set hours', selected: _customHours, onTap: _pickHours),
        ]),
        const SizedBox(height: Sp.x1),
        Text(_meaning, style: AllyType.small(color: c.faint)),
      ],
    );
  }
}
