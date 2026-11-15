import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/know.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// "Getting to know you": one question at a time from a short fixed list (no
/// AI, no cost), on What Ally remembers, never on Today. Tap an answer, type
/// one, or skip. The server decides what is left to ask; with nothing to ask,
/// or offline, the card is simply not there.
class AskCard extends StatefulWidget {
  final LifeRepository repo;

  /// After an answer, so the list below can show what Ally now knows.
  final VoidCallback? onAnswered;
  const AskCard({super.key, required this.repo, this.onAnswered});

  @override
  State<AskCard> createState() => _AskCardState();
}

class _AskCardState extends State<AskCard> {
  final _text = TextEditingController();
  KnowCardData? _data;
  String? _message;
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
      final d = await widget.repo.knowNext();
      if (mounted) setState(() => _data = d);
    } on ApiException catch (_) {
      if (mounted) setState(() => _data = null);
    }
  }

  Future<void> _send({String? answer, bool skip = false}) async {
    final q = _data?.question;
    final given = answer?.trim();
    if (q == null || _busy || (!skip && (given == null || given.isEmpty))) return;
    setState(() => _busy = true);
    try {
      final r = await widget.repo.knowAnswer(q.id, answer: given, skip: skip);
      if (!mounted) return;
      _text.clear();
      setState(() {
        _message = r.message;
        _busy = false;
        // An answer that could not be read keeps the question open to try again.
        if (!r.retry) _data = KnowCardData(answered: (_data?.answered ?? 0) + (skip ? 0 : 1), total: _data?.total ?? 0);
      });
      if (!r.retry && !skip) widget.onAnswered?.call();
      _clear?.cancel();
      _clear = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _message = null);
      });
      if (!r.retry) await _load();
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
    final c = context.ac;
    final d = _data;
    final q = d?.question;
    if (q == null && _message == null) return const SizedBox.shrink();
    return AllyCard(
      child: AnimatedSize(
        duration: Motion.reduced(context) ? Duration.zero : Motion.d2,
        alignment: Alignment.topCenter,
        child: q == null
            ? Text(_message!, style: AllyType.body(color: c.muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  d!.total > 0 ? 'GETTING TO KNOW YOU · ${d.answered} OF ${d.total}' : 'GETTING TO KNOW YOU',
                  style: AllyType.eyebrow(color: c.faint),
                ),
                const SizedBox(height: Sp.x1),
                Text(q.text, style: AllyType.h2(color: c.ink)),
                const SizedBox(height: Sp.x1),
                Text(q.why, style: AllyType.small(color: c.muted)),
                if (_message != null) ...[
                  const SizedBox(height: Sp.x2),
                  Text(_message!, style: AllyType.body(color: c.ink)),
                ],
                if (q.options.isNotEmpty) ...[
                  const SizedBox(height: Sp.x3),
                  Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
                    for (final o in q.options) AllyChip(o, onTap: _busy ? null : () => _send(answer: o)),
                  ]),
                ],
                if (q.allowText) ...[
                  const SizedBox(height: Sp.x2),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: !_busy,
                        maxLength: 200,
                        style: AllyType.body(color: c.ink),
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (v) => _send(answer: v),
                        decoration: InputDecoration(hintText: q.hint ?? 'Or type your own', counterText: '', isDense: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send answer',
                      onPressed: _busy ? null : () => _send(answer: _text.text),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ]),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: AllyButton('Skip for now', kind: AllyButtonKind.ghost, onPressed: _busy ? null : () => _send(skip: true)),
                ),
              ]),
      ),
    );
  }
}
