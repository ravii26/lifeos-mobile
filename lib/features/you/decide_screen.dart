import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart' show placesRefresh;

/// Help me decide: two options and what makes it hard → Ally's suggestion,
/// why, one first step, and a day to check in. Going with one sets that
/// check-in, with Undo. On health, law or large money Ally does not choose.
class DecideScreen extends StatefulWidget {
  final LifeRepository repo;
  const DecideScreen({super.key, required this.repo});

  @override
  State<DecideScreen> createState() => _DecideScreenState();
}

class _DecideScreenState extends State<DecideScreen> {
  static const _hard = [('MONEY', 'Money'), ('TIME', 'Time'), ('FEAR', 'Fear of getting it wrong'), ('PEOPLE', 'Other people'), ('UNSURE', 'Not sure what I want')];

  final _a = TextEditingController();
  final _b = TextEditingController();
  final Set<String> _picked = {};
  bool _busy = false;
  String? _error;
  Json? _answer;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  bool get _ready => _a.text.trim().isNotEmpty && _b.text.trim().isNotEmpty && !_busy;

  Future<void> _ask() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.repo.decide(_a.text.trim(), _b.text.trim(), hard: _picked.toList());
      if (mounted) {
        setState(() {
          _answer = r;
          _busy = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.isNotFound ? 'Help me decide needs the latest server. Deploy it, then try again.' : e.message;
        });
      }
    }
  }

  Future<void> _choose(BuildContext themed, String choice) async {
    final days = asInt(_answer?['checkInDays'], 7);
    setState(() => _busy = true);
    try {
      final r = await widget.repo.chooseDecision(choice, days);
      placesRefresh.value++;
      if (!mounted || !themed.mounted) return;
      final undoId = r.activityId;
      // The toast lives in the app's overlay, so it stays after this screen closes.
      showAllyToast(themed, r.message,
          onUndo: undoId == null
              ? null
              : () async {
                  try {
                    await widget.repo.undo(undoId);
                    placesRefresh.value++;
                  } on ApiException catch (_) {
                    // Nothing else to show: the screen has closed.
                  }
                });
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _busy = false);
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final ans = _answer;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x6), children: [
        Text('Help me decide', style: AllyType.h1(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('Two options. Ally suggests one, says why, and checks in later.', style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x5),
        Text('OPTION A', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x1),
        TextField(
          controller: _a,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          style: AllyType.body(color: c.ink),
          decoration: const InputDecoration(hintText: 'For example: Join the evening class', counterText: ''),
          onChanged: (_) => setState(() => _answer = null),
        ),
        const SizedBox(height: Sp.x3),
        Text('OPTION B', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x1),
        TextField(
          controller: _b,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          style: AllyType.body(color: c.ink),
          decoration: const InputDecoration(hintText: 'For example: Learn at home with videos', counterText: ''),
          onChanged: (_) => setState(() => _answer = null),
        ),
        const SizedBox(height: Sp.x4),
        Text('WHAT MAKES IT HARD? (OPTIONAL)', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final (key, label) in _hard)
            AllyChip(label,
                selected: _picked.contains(key),
                onTap: () => setState(() {
                  _picked.contains(key) ? _picked.remove(key) : _picked.add(key);
                  _answer = null;
                })),
        ]),
        const SizedBox(height: Sp.x5),
        if (_error != null) ...[AllyNote(_error!), const SizedBox(height: Sp.x3)],
        if (ans == null)
          _busy
              ? const AllySkeleton(height: 150, radius: Rad.card)
              : AllyButton('Help me decide', wide: true, onPressed: _ready ? _ask : null)
        else
          _answerCard(themed, c, ans),
      ]),
    );
  }

  Widget _answerCard(BuildContext themed, AllyColors c, Json ans) {
    final pick = asString(ans['pick'], 'EITHER');
    final a = _a.text.trim(), b = _b.text.trim();
    final headline = pick == 'A' ? a : (pick == 'B' ? b : 'Either can work');
    final days = asInt(ans['checkInDays'], 7);
    return Stagger(gap: Sp.x3, children: [
      AllyCard(
        strong: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pick == 'EITHER' ? 'ALLY SAYS' : 'ALLY SUGGESTS', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text(headline, style: AllyType.h2(color: c.ink)),
          const SizedBox(height: Sp.x2),
          Text(asString(ans['why']), style: AllyType.body(color: c.muted)),
          const SizedBox(height: Sp.x3),
          Text('FIRST STEP', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text(asString(ans['firstStep']), style: AllyType.body(color: c.ink)),
          const SizedBox(height: Sp.x2),
          Text('Ally checks in after $days days.', style: AllyType.small(color: c.faint)),
          if (asBool(ans['byCode'])) ...[
            const SizedBox(height: Sp.x1),
            Text('A simple method, without AI.', style: AllyType.small(color: c.faint)),
          ],
        ]),
      ),
      AllyButton('Go with "$a"', kind: pick == 'A' ? AllyButtonKind.main : AllyButtonKind.secondary, wide: true, onPressed: _busy ? null : () => _choose(themed, a)),
      AllyButton('Go with "$b"', kind: pick == 'B' ? AllyButtonKind.main : AllyButtonKind.secondary, wide: true, onPressed: _busy ? null : () => _choose(themed, b)),
      AllyButton('Not yet', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(context).pop()),
    ]);
  }
}
