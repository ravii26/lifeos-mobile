import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/area.dart';
import '../../data/models/tonight.dart';
import '../../data/repositories/life_repository.dart';
import 'guide_style.dart';
import 'mood_picker.dart';

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
          Text('What did you save?', style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
          const SizedBox(height: 8),
          Text('Paste a link to a video, reel or post. Next time, you can share it straight to Ally.',
              style: G.text(17, color: G.muted, height: 1.35)),
          const SizedBox(height: 16),
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
                  borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: GPill('Turn it into a step', primary: true, onTap: () => Navigator.pop(ctx, ctrl.text.trim()))),
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

  // The person picked when this should come back (their own words are fine).
  Future<void> _setMoods(List<String> moods) async {
    final p = _p;
    if (p == null || moods.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fresh = await _repo.setSaveMoods(p.id, moods);
      if (!mounted) return;
      setState(() {
        _p = fresh;
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

  Future<void> _decide(String choice, {String? list}) async {
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
        minutes: choice == 'LATER' ? p.lengthMinutes : null,
        list: list,
      );
      setState(() => _done = switch (choice) {
            'ACTION' when tonight => "It's tonight's one thing now. I'll remind you.",
            'ACTION' => _when == 'LATER'
                ? "Saved with a date. I'll bring it back when it's time."
                : "On your list for this week. I'll pick it on a good night.",
            'SHELF' => "On your hard-days shelf. It'll be there when you need a lift.",
            'LATER' => "In your watch later. I'll bring it up when you have time.",
            'LIST' => 'Added to your ${(list ?? 'list').toLowerCase()} list.',
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

  static String _choiceName(String c) => switch (c) {
        'DO' => 'Do it',
        'LATER' => 'Watch later',
        'LIFT' => 'Lift me up',
        'LIST' => 'Add to a list',
        _ => 'Let it go',
      };

  /// Which list: a few usual ones, the suggested one first, or any name.
  Future<void> _pickList() async {
    final p = _p;
    if (p == null) return;
    final usual = <String>{if (p.listName != null) p.listName!, 'Movies', 'Books', 'Shopping', 'Places', 'Wishlist'}.toList();
    final field = TextEditingController(text: p.listName ?? '');
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: G.card,
        title: Text('Which list?', style: G.text(17, w: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final name in usual) ActionChip(label: Text(name), onPressed: () => Navigator.pop(ctx, name)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: field, decoration: _field('Or type a list name')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, field.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    field.dispose();
    if (chosen != null && chosen.isNotEmpty) await _decide('LIST', list: chosen);
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: G.text(16, color: G.muted),
        filled: true,
        fillColor: G.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  Widget _quiet(String label, VoidCallback onTap) => TextButton(
        onPressed: _busy ? null : onTap,
        style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
        child: Text(label, style: G.text(17, height: 1.2)),
      );

  Widget _summary(SaveProposal p) {
    if (p.summaryState == 'PENDING') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: G.ink)),
          const SizedBox(width: 10),
          Expanded(child: Text('Watching the video for you…', style: G.text(16, color: G.muted, height: 1.3))),
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
          Text('What it says', style: G.text(16, color: G.muted, height: 1.2)),
          const SizedBox(height: 8),
          for (final l in p.summaryLines)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l, style: G.text(18, height: 1.35))),
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
            Text('Done.', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
            const SizedBox(height: 10),
            Text(_done!, style: G.text(19, color: G.muted, height: 1.35)),
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
                  CircularProgressIndicator(color: G.accent, strokeWidth: 2),
                  const SizedBox(height: 20),
                  Text('Reading what you saved…', style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
                  const SizedBox(height: 8),
                  Text('Working out what it is for.', style: G.text(18, color: G.muted, height: 1.35)),
                ]
              : [
                  Text("Couldn't read it.", style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
                  const SizedBox(height: 8),
                  Text(_error!, style: G.text(17, color: G.muted, height: 1.35)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: GPill('Try again', primary: true, onTap: _read)),
                ],
        ),
      );
    }

    final header = [
      Text(p.platform ?? 'You saved', style: G.text(16, color: G.accent, height: 1.2)),
      const SizedBox(height: 8),
      Text(p.contentTitle, style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
      if (p.author != null) ...[
        const SizedBox(height: 6),
        Text(p.author!, style: G.text(16, color: G.muted, height: 1.3)),
      ],
      const SizedBox(height: 18),
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
              style: G.text(19, height: 1.35)),
          const SizedBox(height: 16),
          MoodPicker(selected: p.feelings, busy: _busy, onChanged: _setMoods),
          const SizedBox(height: 16),
          _summary(p),
          if (_error != null) Text(_error!, style: G.text(16, color: G.accent, height: 1.3)),
          const SizedBox(height: 10),
          GPill('Done', primary: true, onTap: () => Navigator.pop(context, true)),
          const SizedBox(height: 4),
          _quiet('Actually, I want to learn from it', () => _correct('LEARN')),
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
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
            decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 2),
                  child: Text(_steps.length > 1 ? 'Instead of just saving it, pick what you will do' : 'Instead of just saving it', style: G.text(16, color: G.accent, height: 1.25)),
                ),
                const SizedBox(height: 8),
                for (final s in _steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Checkbox(
                        value: s.selected,
                        activeColor: G.ink,
                        checkColor: G.onInk,
                        onChanged: (v) => setState(() => s.selected = v ?? false),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TextField(
                            controller: s.action,
                            minLines: 1,
                            maxLines: 3,
                            onChanged: (_) => _edited = true,
                            style: G.text(18, w: FontWeight.w500, height: 1.3),
                            decoration: _field('What will you do with it?'),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: s.minimum,
                            onChanged: (_) => _edited = true,
                            style: G.text(16, height: 1.3),
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
                            Expanded(child: Text('Repeat it as a habit', style: G.text(16, height: 1.25))),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                if (p.reason.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: Text(p.reason, style: G.text(16, color: G.muted, height: 1.35))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('When', style: G.text(16, color: G.muted, height: 1.2)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final (value, label) in _whens)
              ChoiceChip(
                label: Text(label),
                selected: _when == value,
                onSelected: (_) => setState(() => _when = value),
                labelStyle: G.text(16, w: FontWeight.w600, color: _when == value ? G.onInk : G.ink),
                selectedColor: G.accent,
                backgroundColor: G.card,
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
            Text(_error!, style: G.text(16, color: G.accent, height: 1.3)),
          ],
          const SizedBox(height: 20),
          if (p.suggestedChoice != null && p.suggestionReason.isNotEmpty) ...[
            Text('Ally suggests: ${_choiceName(p.suggestedChoice!)}. ${p.suggestionReason}', style: G.text(16, color: G.muted, height: 1.35)),
            const SizedBox(height: 12),
          ],
          GPill(_steps.where((s) => s.selected).length > 1 ? 'Add these' : 'Add to my plan', primary: true, onTap: _busy ? null : () => _decide('ACTION')),
          const SizedBox(height: 10),
          GPill('Watch later', onTap: _busy ? null : () => _decide('LATER')),
          const SizedBox(height: 4),
          _quiet(p.listName != null ? 'Add to my ${p.listName!.toLowerCase()} list' : 'Add to a list', _pickList),
          _quiet('Keep it for how I feel', () => _correct('FEELING')),
          _quiet("Don't need it", () => _decide('DROP')),
        ],
      ),
    );
  }
}
