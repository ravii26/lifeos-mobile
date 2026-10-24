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
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: G.card,
        border: Border.all(color: G.lineSoft, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: q == null
          ? Text(_message!, style: G.text(14, color: G.muted, height: 1.4))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('A quick question${_data!.total > 0 ? ' · ${_data!.answered} of ${_data!.total} answered' : ''}', style: G.label(size: 11, color: G.faint)),
              const SizedBox(height: 6),
              Text(q.text, style: G.voice(17, color: G.ink)),
              const SizedBox(height: 2),
              Text(q.why, style: G.text(12, color: G.muted, height: 1.35)),
              if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: G.text(13, color: G.accent, height: 1.4))),
              if (q.options.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in q.options)
                    ActionChip(
                      label: Text(o, style: G.text(14, w: FontWeight.w600)),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: G.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                      style: G.text(14),
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (v) => _send(answer: v),
                      decoration: InputDecoration(hintText: q.hint ?? 'Or type your own', hintStyle: G.text(13, color: G.faint), isDense: true),
                    ),
                  ),
                  IconButton(onPressed: _busy ? null : () => _send(answer: _text.text), icon: Icon(Icons.arrow_upward_rounded, size: 20, color: G.accent)),
                ]),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : () => _send(skip: true),
                  child: Text('Not now', style: G.text(13, color: G.muted)),
                ),
              ),
            ]),
    );
  }
}
