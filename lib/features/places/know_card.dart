import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/know.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

/// "A quick question so I can help better": one question at a time from a short fixed list (no AI,
/// no cost). Tap an answer, type one, or skip. The server decides when to ask (at most two a day,
/// never while sick or busy) and what it already knows, so most days this shows nothing.
class KnowCard extends StatefulWidget {
  const KnowCard({super.key});

  @override
  State<KnowCard> createState() => _KnowCardState();
}

class _KnowCardState extends State<KnowCard> {
  final _repo = getIt<LifeRepository>();
  final _text = TextEditingController();
  KnowCardData? _data;
  String? _message; // what Ally says after an answer, shown for a few seconds
  bool _busy = false;
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clear?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.knowNext();
      if (mounted) setState(() => _data = d);
    } catch (_) {
      // Offline or the server is waking: no card, nothing to show.
      if (mounted) setState(() => _data = null);
    }
  }

  Future<void> _send({String? answer, bool skip = false}) async {
    final q = _data?.question;
    if (q == null || _busy) return;
    final given = answer?.trim();
    if (!skip && (given == null || given.isEmpty)) return;
    setState(() => _busy = true);
    try {
      final r = await _repo.knowAnswer(q.id, answer: given, skip: skip);
      if (!mounted) return;
      _text.clear();
      setState(() {
        _message = r.message;
        _busy = false;
        // A reply that could not be read keeps the same question open so it can be tried again.
        if (!r.retry) _data = KnowCardData(question: null, answered: (_data?.answered ?? 0) + (skip ? 0 : 1), total: _data?.total ?? 0);
      });
      _clear?.cancel();
      _clear = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _message = null);
      });
      if (!r.retry) {
        // The server may have one more for today; it stops at two.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _data?.question;
    if (q == null && _message == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
      child: q == null
          ? Text(_message!, style: G.text(17, color: G.muted, height: 1.35))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('One quick question', style: G.text(16, color: G.accent, height: 1.2)),
              const SizedBox(height: 6),
              Text(q.text, style: G.text(25, w: FontWeight.w600, height: 1.14, letterSpacing: -0.4)),
              const SizedBox(height: 5),
              Text(q.why, style: G.text(16, color: G.muted, height: 1.35)),
              if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: G.text(16, color: G.accent, height: 1.35))),
              if (q.options.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in q.options)
                    ActionChip(
                      label: Text(o, style: G.text(16, height: 1.2)),
                      backgroundColor: G.surfaceHigh,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: const StadiumBorder(),
                      onPressed: _busy ? null : () => _send(answer: o),
                    ),
                ]),
              ],
              if (q.allowText) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: !_busy,
                      style: G.text(17, height: 1.3),
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (v) => _send(answer: v),
                      decoration: InputDecoration(hintText: q.hint ?? 'Or type your own', hintStyle: G.text(17, color: G.faint, height: 1.3), isDense: true),
                    ),
                  ),
                  IconButton(onPressed: _busy ? null : () => _send(answer: _text.text), icon: Icon(Icons.arrow_upward_rounded, size: 20, color: G.accent)),
                ]),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : () => _send(skip: true),
                  child: Text('Skip for now', style: G.text(16, color: G.ink, height: 1.2)),
                ),
              ),
            ]),
    );
  }
}
