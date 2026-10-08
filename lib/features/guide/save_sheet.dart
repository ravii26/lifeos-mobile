import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/area.dart';
import '../../data/models/tonight.dart';
import '../../data/repositories/life_repository.dart';
import 'guide_style.dart';

/// What the person shared: a link/text, or a screenshot.
class SaveSource {
  final String? text;
  final String? imagePath;
  final String? imageMime;
  // Reopen a save that already exists (from the Saves list) instead of reading a new one.
  final String? existingId;
  const SaveSource({this.text, this.imagePath, this.imageMime, this.existingId});
}

/// Saved something → one action. Opens from the share sheet or the Tonight
/// screen. Returns true when anything was created (so callers can refresh).
Future<bool> openSaveSheet(BuildContext context, SaveSource source) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: G.bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: _SaveSheet(source)),
  );
  return result ?? false;
}

/// Asks for a link to paste, then opens the save flow.
Future<bool> openPasteSave(BuildContext context) async {
  final ctrl = TextEditingController();
  final text = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: G.bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What did you save?', style: G.display(26)),
          const SizedBox(height: 6),
          Text('Paste a link to a video, reel or post. Tip: next time, use Share → Ally.',
              style: G.voice(16)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: G.text(16),
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'https://… or describe it',
              hintStyle: G.text(16, color: G.muted),
              filled: true,
              fillColor: G.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          GButton('Turn it into an action', onTap: () => Navigator.pop(ctx, ctrl.text.trim())),
        ],
      ),
    ),
  );
  ctrl.dispose();
  if (text == null || text.isEmpty || !context.mounted) return false;
  return openSaveSheet(context, SaveSource(text: text));
}

const _whens = [('TONIGHT', 'Tonight'), ('THIS_WEEK', 'This week'), ('LATER', 'Later')];

/// One editable step proposed from the save.
class _Step {
  final TextEditingController action;
  final TextEditingController minimum;
  bool selected = true;
  bool habit;
  _Step(SaveActionDraft d)
      : action = TextEditingController(text: d.action),
        minimum = TextEditingController(text: d.minimum),
        habit = d.as == 'HABIT';
  void dispose() {
    action.dispose();
    minimum.dispose();
  }
}

class _SaveSheet extends StatefulWidget {
  final SaveSource source;
  const _SaveSheet(this.source);

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  final _repo = getIt<LifeRepository>();

  SaveProposal? _p;
  List<_Step> _steps = [];
  bool _edited = false; // once you edit a step, a late video summary won't overwrite it
  List<Area> _areas = const [];
  String? _areaId;
  String _when = 'THIS_WEEK';
  bool _busy = false;
  String? _error;
  String? _done; // confirmation text once decided
  Timer? _poll;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  void _setSteps(SaveProposal p) {
    for (final s in _steps) {
      s.dispose();
    }
    _steps = [for (final a in p.actions) _Step(a)];
    if (_steps.isEmpty && p.action.isNotEmpty) {
      _steps = [_Step(SaveActionDraft(p.action, p.minimum, 'TODO', p.when))];
    }
    _edited = false;
  }

  Future<void> _read() async {
    setState(() => _error = null);
    try {
      final s = widget.source;
      final results = await Future.wait([
        s.existingId != null
            ? _repo.getSave(s.existingId!)
            : s.imagePath != null
                ? _repo.createSaveFromImage(s.imagePath!,
                    mimeType: s.imageMime ?? 'image/jpeg', caption: s.text)
                : _repo.createSave(s.text ?? ''),
        _repo.areas(),
      ]);
      final p = results[0] as SaveProposal;
      if (!mounted) return;
      setState(() {
        _p = p;
        _areas = (results[1] as List<Area>).where((a) => a.isActive).toList();
        _setSteps(p);
        _areaId = _areas.any((a) => a.id == p.areaId) ? p.areaId : null;
        _when = p.when;
      });
      _startPolling();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // A YouTube link is watched in the background: check back until it is read.
  void _startPolling() {
    _poll?.cancel();
    if (_p?.summaryState != 'PENDING') return;
    _polls = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      _polls++;
      final id = _p?.id;
      if (id == null || !mounted || _polls > 30) {
        t.cancel();
        return;
      }
      try {
        final fresh = await _repo.getSave(id);
        if (!mounted) return;
        setState(() {
          final changedPurpose = fresh.purpose != _p!.purpose;
          _p = fresh;
          if (!_edited || changedPurpose) _setSteps(fresh);
        });
        if (fresh.summaryState != 'PENDING') t.cancel();
      } on ApiException {
        // keep waiting; the next check may work
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _correct(String purpose) async {
    final p = _p;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final fresh = await _repo.setSavePurpose(p.id, purpose);
      if (!mounted) return;
      setState(() {
        _p = fresh;
        _setSteps(fresh);
        _when = fresh.when;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  Future<void> _decide(String choice) async {
    final p = _p;
    if (p == null) return;
    final picked = [
      for (final s in _steps)
        if (s.selected && s.action.text.trim().isNotEmpty)
          {
            'action': s.action.text.trim(),
            'minimum': s.minimum.text.trim(),
            'as': s.habit ? 'HABIT' : 'TODO',
            'when': _when,
            if (_areaId != null) 'areaId': _areaId!,
          },
    ];
    if (choice == 'ACTION' && picked.isEmpty) {
      setState(() => _error = 'Pick at least one step.');
      return;
    }
    setState(() => _busy = true);
    try {
      final tonight = await _repo.decideSave(
        p.id,
        choice: choice,
        actions: choice == 'ACTION' ? picked : null,
      );
      setState(() => _done = switch (choice) {
            'ACTION' when tonight => "It's tonight's one thing now. I'll remind you.",
            'ACTION' => _when == 'LATER'
                ? "Saved with a date. I'll bring it back when it's time."
                : "On your list for this week. I'll pick it on a good night.",
            'SHELF' => "On your hard-days shelf. It'll be there when you need a lift.",
            _ => 'Let go. One less thing to carry.',
          });
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context, choice != 'DROP');
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: G.text(16, color: G.muted),
        filled: true,
        fillColor: G.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  Widget _summary(SaveProposal p) {
    if (p.summaryState == 'PENDING') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: G.ink)),
          const SizedBox(width: 10),
          Expanded(child: Text('Watching the video for you…', style: G.text(14, color: G.muted))),
        ]),
      );
    }
    if (p.summaryState == 'UNAVAILABLE') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text("I couldn't watch this one, so these steps come from its title.", style: G.text(14, color: G.muted)),
      );
    }
    if (p.summaryState == 'READY' && p.summaryLines.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What it says', style: G.text(15, w: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final l in p.summaryLines)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('· $l', style: G.text(15))),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Done.', style: G.display(36)),
            const SizedBox(height: 10),
            Text(_done!, style: G.voice(19)),
          ],
        ),
      );
    }
    final p = _p;
    if (p == null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _error == null
              ? [
                  CircularProgressIndicator(color: G.ink, strokeWidth: 2),
                  const SizedBox(height: 20),
                  Text('Reading what you saved…', style: G.display(26)),
                  const SizedBox(height: 8),
                  Text('Working out what it is for.', style: G.voice(17)),
                ]
              : [
                  Text("Couldn't read it.", style: G.display(28)),
                  const SizedBox(height: 8),
                  Text(_error!, style: G.text(15, color: G.muted)),
                  const SizedBox(height: 20),
                  GButton('Try again', onTap: _read),
                ],
        ),
      );
    }

    final header = [
      Text(p.platform ?? 'You saved', style: G.text(13, color: G.muted, w: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(p.contentTitle, style: G.display(24, w: FontWeight.w800)),
      if (p.author != null) ...[
        const SizedBox(height: 4),
        Text(p.author!, style: G.text(14, color: G.muted)),
      ],
      const SizedBox(height: 14),
    ];

    // A feeling save is already on the shelf. One tap if Ally guessed wrong.
    if (p.shelved) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          ...header,
          Text(
              p.feelings.isEmpty
                  ? "Kept for hard days. I'll bring it back when you need a lift."
                  : "Kept for days you feel ${p.feelings.join(', ')}. I'll bring it back then.",
              style: G.voice(19)),
          const SizedBox(height: 16),
          _summary(p),
          if (_error != null) Text(_error!, style: G.text(14, color: const Color(0xFFB3261E))),
          const SizedBox(height: 10),
          GButton('Done', onTap: () => Navigator.pop(context, true)),
          const SizedBox(height: 8),
          GButton('Not for hard days: I want to learn from it', primary: false, onTap: _busy ? null : () => _correct('LEARN')),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          ...header,
          _summary(p),
          Text('Saving it changes nothing. Doing one thing with it does.', style: G.voice(18)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(color: G.tint, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_steps.length > 1 ? 'Pick what you will do' : 'Your step', style: G.text(15, color: G.tintInk, w: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final s in _steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Checkbox(
                        value: s.selected,
                        activeColor: G.ink,
                        onChanged: (v) => setState(() => s.selected = v ?? false),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TextField(
                            controller: s.action,
                            minLines: 1,
                            maxLines: 3,
                            onChanged: (_) => _edited = true,
                            style: G.text(16, w: FontWeight.w700),
                            decoration: _field('What will you do with it?'),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: s.minimum,
                            onChanged: (_) => _edited = true,
                            style: G.text(14),
                            decoration: _field('2-minute version'),
                          ),
                          Row(children: [
                            Switch(
                              value: s.habit,
                              activeThumbColor: G.ink,
                              onChanged: (v) => setState(() {
                                s.habit = v;
                                _edited = true;
                              }),
                            ),
                            Text('Repeat it as a habit', style: G.text(14, color: G.tintInk)),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                if (p.reason.isNotEmpty) Text(p.reason, style: G.text(14, color: G.tintInk)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('When', style: G.text(14, color: G.muted, w: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final (value, label) in _whens)
              ChoiceChip(
                label: Text(label),
                selected: _when == value,
                onSelected: (_) => setState(() => _when = value),
                labelStyle: G.text(14, w: FontWeight.w700, color: _when == value ? Colors.white : G.ink),
                selectedColor: G.ink,
                backgroundColor: G.soft,
                showCheckmark: false,
                side: BorderSide.none,
                shape: const StadiumBorder(),
              ),
          ]),
          if (_areas.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _areaId,
              decoration: _field('Which area?'),
              style: G.text(16),
              dropdownColor: G.card,
              items: [for (final a in _areas) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (v) => setState(() => _areaId = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: G.text(14, color: const Color(0xFFB3261E))),
          ],
          const SizedBox(height: 22),
          GButton(
            _steps.where((s) => s.selected).length > 1 ? 'Make these my actions' : 'Make it my action',
            onTap: _busy ? null : () => _decide('ACTION'),
          ),
          const SizedBox(height: 8),
          GButton('This is for hard days', primary: false, onTap: _busy ? null : () => _correct('FEELING')),
          TextButton(
            onPressed: _busy ? null : () => _decide('DROP'),
            child: Text("Let it go, I won't use it", style: G.text(15, color: G.muted, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
