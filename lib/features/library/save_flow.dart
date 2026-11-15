import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/tonight.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../guide/save_sheet.dart' show SaveSource;

export '../guide/save_sheet.dart' show SaveSource;

/// Why are you saving this? → one step. Opens from the share sheet, from
/// Talk, and from Library → Saved. Returns true when something was kept.
Future<bool> openSaveFlow(BuildContext context, SaveSource source, {LifeRepository? repo}) async {
  final kept = await showAllySheet<bool>(context, builder: (_) => SaveFlow(source: source, repo: repo));
  return kept ?? false;
}

/// Asks for a link, then opens the flow.
Future<bool> openPasteSaveFlow(BuildContext context, {LifeRepository? repo}) async {
  final text = await showAllySheet<String>(context, builder: (ctx) => const _Paste());
  if (text == null || text.trim().isEmpty || !context.mounted) return false;
  return openSaveFlow(context, SaveSource(text: text.trim()), repo: repo);
}

class _Paste extends StatefulWidget {
  const _Paste();

  @override
  State<_Paste> createState() => _PasteState();
}

class _PasteState extends State<_Paste> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Save a link', style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x1),
      Text('Paste a video, reel or post. Next time, tap Share in the app and pick Ally.', style: AllyType.body(color: c.muted)),
      const SizedBox(height: Sp.x3),
      TextField(
        controller: _c,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        maxLength: 2000,
        style: AllyType.body(color: c.ink),
        decoration: const InputDecoration(hintText: 'https://… or describe it', counterText: ''),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Sp.x3),
      AllyButton('Next', wide: true, onPressed: _c.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_c.text)),
    ]);
  }
}

enum SaveWhy {
  doIt('To do something with it', 'Ally turns it into one small step'),
  later('To watch later', 'Kept on a short list, brought up when you have time'),
  feel('For a day when I feel low', 'Shown when you tap "I\'m feeling…"');

  final String title;
  final String sub;
  const SaveWhy(this.title, this.sub);
}

class SaveFlow extends StatefulWidget {
  final SaveSource source;
  final LifeRepository? repo;
  const SaveFlow({super.key, required this.source, this.repo});

  @override
  State<SaveFlow> createState() => _SaveFlowState();
}

class _SaveFlowState extends State<SaveFlow> {
  late final LifeRepository _repo = widget.repo ?? getIt<LifeRepository>();
  SaveProposal? _p;
  String? _error;
  SaveWhy? _why;
  bool _busy = false;
  Timer? _poll;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    // Reading starts at once, while the question is answered.
    _read();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    setState(() => _error = null);
    try {
      final s = widget.source;
      final p = s.existingId != null
          ? await _repo.getSave(s.existingId!)
          : s.imagePath != null
              ? await _repo.createSaveFromImage(s.imagePath!, mimeType: s.imageMime ?? 'image/jpeg', caption: s.text)
              : await _repo.createSave(s.text ?? '');
      if (!mounted) return;
      setState(() => _p = p);
      _watch();
      // Chosen "later" or "a low day" before the link was read: save it now.
      if (_why != null && _why != SaveWhy.doIt) await _finish();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // A video is watched in the background: check back until it is read.
  void _watch() {
    _poll?.cancel();
    if (_p?.summaryState != 'PENDING') return;
    _polls = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      final id = _p?.id;
      if (id == null || !mounted || ++_polls > 30) {
        t.cancel();
        return;
      }
      try {
        final fresh = await _repo.getSave(id);
        if (!mounted) return;
        setState(() => _p = fresh);
        if (fresh.summaryState != 'PENDING') t.cancel();
      } on ApiException {
        // The next check may work.
      }
    });
  }

  SaveActionDraft? get _step {
    final p = _p;
    if (p == null) return null;
    if (p.actions.isNotEmpty) return p.actions.first;
    return p.action.isEmpty ? null : SaveActionDraft(p.action, p.minimum, 'TODO', p.when);
  }

  bool get _reading => _p == null || (_p!.summaryState == 'PENDING' && _step == null);

  Future<void> _choose(SaveWhy why) async {
    setState(() => _why = why);
    if (why == SaveWhy.doIt) return; // the step is shown first
    if (_p == null) return; // decided once the save is read
    await _finish();
  }

  Future<void> _finish({bool keepOnly = false}) async {
    final p = _p;
    final why = _why;
    if (p == null || why == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String message;
      if (why == SaveWhy.doIt && !keepOnly) {
        final s = _step!;
        await _repo.decideSave(p.id, choice: 'ACTION', actions: [
          {'action': s.action, 'minimum': s.minimum, 'as': s.as, 'when': s.when, if (p.areaId != null) 'areaId': p.areaId!},
        ]);
        message = 'Added: ${s.action}';
      } else if (why == SaveWhy.feel) {
        await _repo.setSaveMoods(p.id, const ['low']);
        await _repo.decideSave(p.id, choice: 'SHELF');
        message = 'Kept for a low day. It is in Library → Saved.';
      } else {
        await _repo.decideSave(p.id, choice: 'LATER', minutes: p.lengthMinutes);
        message = 'On your watch-later list. It is in Library → Saved.';
      }
      if (!mounted) return;
      showAllyToast(context, message);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  String get _title {
    final p = _p;
    if (p != null && p.contentTitle.isNotEmpty) return p.contentTitle;
    final t = widget.source.text?.trim() ?? '';
    if (t.isNotEmpty) return t;
    return widget.source.imagePath != null ? 'A screenshot' : 'Something you saved';
  }

  String? get _meta {
    final p = _p;
    if (p == null) return null;
    final parts = [
      if (p.platform != null) p.platform!,
      if (p.author != null) p.author!,
      if (p.lengthMinutes != null && p.lengthMinutes! > 0) '${p.lengthMinutes} min',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final why = _why;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SAVED', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text(_title, maxLines: 3, overflow: TextOverflow.ellipsis, style: AllyType.body(color: c.ink, w: FontWeight.w600)),
          if (_meta != null) Text(_meta!, style: AllyType.small(color: c.faint)),
        ]),
      ),
      const SizedBox(height: Sp.x4),
      if (_error != null) ...[
        AllyNote(_error!, actionLabel: _p == null ? 'Try again' : null, onAction: _p == null ? _read : null),
        const SizedBox(height: Sp.x3),
      ],
      if (why == null) ...[
        Text('Why are you saving this?', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x3),
        for (final w in SaveWhy.values) ...[
          AllyCard(
            onTap: () => _choose(w),
            padding: const EdgeInsets.all(Sp.x4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.title, style: AllyType.body(color: c.ink, w: FontWeight.w600)),
                  Text(w.sub, style: AllyType.small(color: c.muted)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.faint),
            ]),
          ),
          const SizedBox(height: Sp.x2),
        ],
      ] else if (why == SaveWhy.doIt && _reading) ...[
        Text('Finding the one useful step…', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x3),
        const AllySkeleton(height: 120, radius: Rad.card),
      ] else if (why == SaveWhy.doIt && _step == null) ...[
        Text('No clear step in this one.', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('Keep it to watch later, or let it go.', style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x3),
        AllyButton('Keep it to watch later', wide: true, onPressed: _busy ? null : () => _finish(keepOnly: true)),
      ] else if (why == SaveWhy.doIt) ...[
        AllyCard(
          strong: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ONE STEP FROM THIS', style: AllyType.eyebrow(color: c.faint)),
            const SizedBox(height: Sp.x1),
            Text(_step!.action, style: AllyType.h2(color: c.ink)),
            if (_step!.minimum.isNotEmpty) ...[
              const SizedBox(height: Sp.x1),
              Text('Smaller version: ${_step!.minimum}', style: AllyType.small(color: c.muted)),
            ],
            const SizedBox(height: Sp.x2),
            Text('Watching is not the step; doing is.', style: AllyType.small(color: c.faint)),
          ]),
        ),
        const SizedBox(height: Sp.x3),
        AllyButton('Add this step', wide: true, onPressed: _busy ? null : _finish),
        const SizedBox(height: Sp.x2),
        AllyButton('Just keep it', kind: AllyButtonKind.secondary, wide: true, onPressed: _busy ? null : () => _finish(keepOnly: true)),
      ] else ...[
        // Later or a low day: saved as soon as the link is read.
        Text(_p == null ? 'Reading the link…' : 'Saving…', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x3),
        if (_p != null && !_busy) AllyButton('Save it', wide: true, onPressed: _finish) else const AllySkeleton(height: 48, radius: Rad.button),
      ],
    ]);
  }
}
