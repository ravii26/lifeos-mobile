import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import 'guide_style.dart';

/// "When should this come back?" A few common moods, the ones the person made
/// up before, and a box for a new one ("before an exam", "bored", "need to
/// focus"). Up to three can be chosen; at least one stays chosen.
class MoodPicker extends StatefulWidget {
  final List<String> selected;
  final bool busy;
  final ValueChanged<List<String>> onChanged;
  const MoodPicker({super.key, required this.selected, required this.onChanged, this.busy = false});

  @override
  State<MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<MoodPicker> {
  final _repo = getIt<LifeRepository>();
  final _own = TextEditingController();
  List<String> _suggested = const ['tired', 'low', 'stressed', 'unmotivated', 'stuck', 'anxious'];
  List<String> _mine = const [];
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _repo.saveMoods().then((m) {
      if (mounted) {
        setState(() {
          _suggested = m.suggested;
          _mine = m.mine;
        });
      }
    }).catchError((_) {
      // The common moods are enough if the list can't load.
    });
  }

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  String _label(String m) => m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';

  // What's chosen first, then their own, then the common ones, each once.
  List<String> get _options {
    final seen = <String>{};
    return [
      for (final m in [...widget.selected, ..._mine, ..._suggested])
        if (seen.add(m.toLowerCase())) m,
    ];
  }

  void _toggle(String m) {
    final now = [...widget.selected];
    final at = now.indexWhere((x) => x.toLowerCase() == m.toLowerCase());
    if (at >= 0) {
      if (now.length == 1) return; // keep at least one
      now.removeAt(at);
    } else {
      if (now.length >= 3) now.removeAt(0);
      now.add(m);
    }
    widget.onChanged(now);
  }

  void _addOwn() {
    final t = _own.text.trim();
    if (t.length < 2) return;
    _own.clear();
    setState(() => _adding = false);
    _toggle(t);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.selected.map((e) => e.toLowerCase()).toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bring it back when I feel', style: G.text(14, color: G.muted, w: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final m in _options)
          ChoiceChip(
            label: Text(_label(m)),
            selected: on.contains(m.toLowerCase()),
            onSelected: widget.busy ? null : (_) => _toggle(m),
            labelStyle: G.text(14, w: FontWeight.w700, color: on.contains(m.toLowerCase()) ? Colors.white : G.ink),
            selectedColor: G.ink,
            backgroundColor: G.soft,
            showCheckmark: false,
            side: BorderSide.none,
            shape: const StadiumBorder(),
          ),
        ActionChip(
          label: Text(_adding ? 'Cancel' : 'Something else'),
          onPressed: widget.busy ? null : () => setState(() => _adding = !_adding),
          labelStyle: G.text(14, w: FontWeight.w700, color: G.muted),
          backgroundColor: G.bg,
          side: BorderSide(color: G.lineSoft),
          shape: const StadiumBorder(),
        ),
      ]),
      if (_adding) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _own,
              autofocus: true,
              maxLength: 24,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addOwn(),
              style: G.text(16),
              decoration: const InputDecoration(hintText: 'e.g. before an exam, bored, need to focus', counterText: ''),
            ),
          ),
          TextButton(onPressed: _addOwn, child: Text('Add', style: G.text(15, w: FontWeight.w700))),
        ]),
      ],
    ]);
  }
}
