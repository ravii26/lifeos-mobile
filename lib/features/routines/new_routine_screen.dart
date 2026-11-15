import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../chat/starters.dart' show talkRequest;
import 'routine_reminders.dart';
import 'routine_when_sheet.dart';

/// A new routine: what, which area, when, a smaller version for hard days and
/// an optional reminder. Pops with true when one was added.
class NewRoutineScreen extends StatefulWidget {
  final LifeRepository repo;

  /// The areas to choose from, in the person's order: (id, name).
  final List<(String, String)> areas;
  final String? areaId;

  const NewRoutineScreen({super.key, required this.repo, required this.areas, this.areaId});

  @override
  State<NewRoutineScreen> createState() => _NewRoutineScreenState();
}

class _NewRoutineScreenState extends State<NewRoutineScreen> {
  final _title = TextEditingController();
  final _smaller = TextEditingController();
  late String? _areaId = widget.areaId ?? (widget.areas.isEmpty ? null : widget.areas.first.$1);
  RoutineWhen _when = const RoutineWhen();
  TimeOfDay? _reminder;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _smaller.dispose();
    super.dispose();
  }

  bool get _ready => _title.text.trim().isNotEmpty && _areaId != null && _when.valid && !_saving;

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.createHabit(
        title: _title.text.trim(),
        areaId: _areaId!,
        frequency: _when.frequency,
        specificDays: _when.frequency == 'CUSTOM' ? _when.days : null,
        weeklyTarget: _when.frequency == 'WEEKLY' ? _when.timesAWeek : null,
        timeBlock: _when.part,
        minimumVersion: _smaller.text.trim(),
        reminderTime: _reminder == null ? null : _hhmm(_reminder!),
      );
      await syncRoutineReminders(widget.repo);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyTheme.dark(), child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final c = context.ac;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('New routine')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x6),
        children: [
          if (widget.areas.isEmpty) ...[
            AllyCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add an area first', style: AllyType.h2(color: c.ink)),
                const SizedBox(height: Sp.x1),
                Text('A routine belongs to a part of your life. Add one on the Areas tab, or tell Ally.', style: AllyType.body(color: c.muted)),
                const SizedBox(height: Sp.x4),
                AllyButton('Tell Ally', kind: AllyButtonKind.secondary, onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  talkRequest.value++;
                }),
              ]),
            ),
          ] else ...[
            Text('WHAT', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x2),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              style: AllyType.body(color: c.ink),
              decoration: const InputDecoration(hintText: 'For example: Read 10 pages', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Sp.x4),
            Text('AREA', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x2),
            Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
              for (final (id, name) in widget.areas)
                AllyChip(name, selected: _areaId == id, onTap: () => setState(() => _areaId = id)),
            ]),
            const SizedBox(height: Sp.x4),
            RoutineWhenEditor(value: _when, onChanged: (v) => setState(() => _when = v)),
            const SizedBox(height: Sp.x4),
            Text('SMALLER VERSION', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x2),
            TextField(
              controller: _smaller,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              style: AllyType.body(color: c.ink),
              decoration: const InputDecoration(hintText: 'For a hard day, e.g. "read one page"', counterText: ''),
            ),
            const SizedBox(height: Sp.x4),
            Text('REMINDER', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x2),
            Row(children: [
              Expanded(child: Text(_reminder == null ? 'No reminder' : _reminder!.format(context), style: AllyType.body(color: c.ink))),
              if (_reminder != null)
                AllyButton('Remove', kind: AllyButtonKind.ghost, onPressed: () => setState(() => _reminder = null)),
              AllyButton(_reminder == null ? 'Set a time' : 'Change',
                  kind: AllyButtonKind.secondary,
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _reminder ?? const TimeOfDay(hour: 8, minute: 0));
                    if (t != null && mounted) setState(() => _reminder = t);
                  }),
            ]),
            const SizedBox(height: Sp.x5),
            if (_error != null) ...[AllyNote(_error!), const SizedBox(height: Sp.x3)],
            AllyButton(_saving ? 'Adding…' : 'Add routine', wide: true, onPressed: _ready ? _save : null),
          ],
        ],
      ),
    );
  }
}
