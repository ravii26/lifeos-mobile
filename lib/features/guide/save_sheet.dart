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
  const SaveSource({this.text, this.imagePath, this.imageMime});
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

class _SaveSheet extends StatefulWidget {
  final SaveSource source;
  const _SaveSheet(this.source);

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  final _repo = getIt<LifeRepository>();
  final _action = TextEditingController();
  final _minimum = TextEditingController();

  SaveProposal? _p;
  List<Area> _areas = const [];
  String? _areaId;
  String _when = 'THIS_WEEK';
  bool _busy = false;
  String? _error;
  String? _done; // confirmation text once decided

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() => _error = null);
    try {
      final s = widget.source;
      final results = await Future.wait([
        s.imagePath != null
            ? _repo.createSaveFromImage(s.imagePath!,
                mimeType: s.imageMime ?? 'image/jpeg', caption: s.text)
            : _repo.createSave(s.text ?? ''),
        _repo.areas(),
      ]);
      final p = results[0] as SaveProposal;
      setState(() {
        _p = p;
        _areas = (results[1] as List<Area>).where((a) => a.isActive).toList();
        _action.text = p.action;
        _minimum.text = p.minimum;
        _areaId = _areas.any((a) => a.id == p.areaId) ? p.areaId : null;
        _when = p.when;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _action.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Future<void> _decide(String choice) async {
    final p = _p;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final tonight = await _repo.decideSave(
        p.id,
        choice: choice,
        action: choice == 'ACTION' ? _action.text.trim() : null,
        minimum: choice == 'ACTION' ? _minimum.text.trim() : null,
        areaId: choice == 'ACTION' ? _areaId : null,
        when: choice == 'ACTION' ? _when : null,
      );
      setState(() => _done = switch (choice) {
            'ACTION' when tonight => "It's tonight's one thing now. I'll remind you.",
            'ACTION' => _when == 'LATER'
                ? "Saved with a date. I'll bring it back when it's time."
                : "It's on your list for this week. I'll pick it on a good night.",
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
                  const CircularProgressIndicator(color: G.ink, strokeWidth: 2),
                  const SizedBox(height: 20),
                  Text('Reading what you saved…', style: G.display(26)),
                  const SizedBox(height: 8),
                  Text('Finding the one thing it could change for you.', style: G.voice(17)),
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Text(
            [if (p.platform != null) p.platform!.toUpperCase(), 'YOU SAVED'].join(' · '),
            style: G.label(),
          ),
          const SizedBox(height: 6),
          Text(p.contentTitle, style: G.display(24, w: FontWeight.w800)),
          if (p.author != null) ...[
            const SizedBox(height: 4),
            Text(p.author!, style: G.text(14, color: G.muted)),
          ],
          const SizedBox(height: 18),
          Text('Saving it changes nothing. Doing one thing with it does.', style: G.voice(18)),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(color: G.tint, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR ACTION', style: G.label(color: G.tintInk)),
                const SizedBox(height: 8),
                TextField(
                  controller: _action,
                  minLines: 1,
                  maxLines: 3,
                  style: G.text(17, w: FontWeight.w700),
                  decoration: _field('What will you do with it?'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _minimum,
                  style: G.text(15),
                  decoration: _field('2-minute version'),
                ),
                if (p.reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(p.reason, style: G.text(14, color: G.tintInk)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text('WHEN', style: G.label()),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final (value, label) in _whens)
              ChoiceChip(
                label: Text(label),
                selected: _when == value,
                onSelected: (_) => setState(() => _when = value),
                labelStyle: G.text(14,
                    w: FontWeight.w700, color: _when == value ? Colors.white : G.ink),
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
              items: [
                for (final a in _areas) DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _areaId = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: G.text(14, color: const Color(0xFFB3261E))),
          ],
          const SizedBox(height: 22),
          GButton('Make it my action', onTap: _busy ? null : () => _decide('ACTION')),
          const SizedBox(height: 8),
          GButton(
            p.looksLikeMotivation ? 'Keep it for hard days (good fit)' : 'Keep it for hard days',
            primary: false,
            onTap: _busy ? null : () => _decide('SHELF'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _decide('DROP'),
            child: Text("Let it go, I won't use it",
                style: G.text(15, color: G.muted, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
