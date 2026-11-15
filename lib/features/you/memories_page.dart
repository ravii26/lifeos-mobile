import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'ask_card.dart';
import 'you_page.dart';

/// What Ally remembers: in your own words where it has them. Mark something
/// private, say it is still true, or forget it.
///
/// Forgetting is permanent on the server, so it waits until the Undo toast has
/// gone: until then it is only hidden and Undo simply brings it back.
class MemoriesPage extends StatefulWidget {
  final LifeRepository repo;

  /// How long Undo stays offered before forgetting happens.
  final Duration forgetAfter;
  const MemoriesPage({super.key, required this.repo, this.forgetAfter = const Duration(seconds: 5)});

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> {
  List<MemoryItem>? _items;
  String? _error;
  final Map<String, Timer> _forgetting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Leaving the page: what was waiting to be forgotten is forgotten now.
    for (final e in _forgetting.entries) {
      e.value.cancel();
      widget.repo.deleteMemory(e.key).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repo.memories();
      if (mounted) {
        setState(() {
          _items = r;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _items == null) setState(() => _error = e.message);
    }
  }

  void _forget(BuildContext themed, MemoryItem m) {
    setState(() {});
    _forgetting[m.id] = Timer(widget.forgetAfter, () async {
      _forgetting.remove(m.id);
      try {
        await widget.repo.deleteMemory(m.id);
        await _load();
      } on ApiException catch (e) {
        if (themed.mounted) showAllyToast(themed, e.message);
        if (mounted) setState(() {});
      }
    });
    showAllyToast(themed, 'Forgotten.', duration: widget.forgetAfter - const Duration(milliseconds: 300), onUndo: () {
      _forgetting.remove(m.id)?.cancel();
      if (mounted) setState(() {});
    });
  }

  Future<void> _private(BuildContext themed, MemoryItem m) async {
    try {
      await widget.repo.setMemoryPrivate(m.id, !m.sensitive);
      await _load();
      if (!themed.mounted) return;
      showAllyToast(themed, m.sensitive ? 'Ally may bring this up again.' : 'Private: Ally won\'t bring this up unless you do.', onUndo: () async {
        await widget.repo.setMemoryPrivate(m.id, m.sensitive);
        await _load();
      });
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  Future<void> _stillTrue(BuildContext themed, MemoryItem m) async {
    try {
      await widget.repo.restoreMemory(m.id);
      await _load();
      if (themed.mounted) showAllyToast(themed, 'Counted as true again.');
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  Future<void> _open(BuildContext themed, MemoryItem m) async {
    final choice = await showAllySheet<String>(
      themed,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(m.content, style: AllyType.h2(color: ctx.ac.ink)),
        if (m.quote != null) ...[
          const SizedBox(height: Sp.x2),
          Text('Your words: “${m.quote}”', style: AllyType.body(color: ctx.ac.muted)),
        ],
        const SizedBox(height: Sp.x4),
        if (m.isCurrent)
          AllyButton(m.sensitive ? 'Ally may bring it up' : 'Keep it private', kind: AllyButtonKind.secondary, wide: true, onPressed: () => Navigator.of(ctx).pop('private'))
        else
          AllyButton('Still true', kind: AllyButtonKind.secondary, wide: true, onPressed: () => Navigator.of(ctx).pop('true')),
        AllyButton('Forget this', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(ctx).pop('forget')),
      ]),
    );
    if (choice == null || !themed.mounted) return;
    switch (choice) {
      case 'private':
        await _private(themed, m);
      case 'true':
        await _stillTrue(themed, m);
      case 'forget':
        _forget(themed, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items?.where((m) => !_forgetting.containsKey(m.id)).toList();
    return YouPage(
      title: 'What Ally remembers',
      sub: 'Tap one to keep it private, say it is still true, or forget it.',
      loading: items == null && _error == null,
      error: items == null ? _error : null,
      onRetry: _load,
      onRefresh: _load,
      children: (themed, c) {
        final current = items!.where((m) => m.isCurrent).toList();
        final past = items.where((m) => !m.isCurrent).toList();
        Widget row(MemoryItem m) => Pressable(
              scale: 0.985,
              onTap: () => _open(themed, m),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.content, style: AllyType.body(color: m.isCurrent ? c.ink : c.faint)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      m.saidByYou ? 'You said' : 'Ally noticed',
                      if (m.sensitive) 'Private',
                      if (m.quote != null) '“${m.quote}”',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AllyType.small(color: c.faint),
                  ),
                ]),
              ),
            );
        return [
          AskCard(key: const ValueKey('ask'), repo: widget.repo, onAnswered: _load),
          if (items.isEmpty) Text('Nothing yet. Talk to Ally and it will start to learn.', style: AllyType.body(color: c.muted)),
          if (current.isNotEmpty) youRows(c, [for (final m in current) row(m)]),
          if (past.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('NO LONGER TRUE', style: AllyType.eyebrow(color: c.faint)),
              const SizedBox(height: Sp.x2),
              youRows(c, [for (final m in past) row(m)]),
            ]),
        ];
      },
    );
  }
}
