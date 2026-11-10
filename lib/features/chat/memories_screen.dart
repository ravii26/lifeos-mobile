import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

const _kindLabel = {
  'FACT': 'About you',
  'PREFERENCE': 'What you like',
  'GOAL': 'What you want',
  'STRUGGLE': 'What is hard',
  'FEELING': 'How you felt',
  'PERSON': 'People',
  'EVENT': 'What happened',
};

/// Everything Ally remembers, grouped, each one changeable or deletable.
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final _repo = getIt<LifeRepository>();
  List<MemoryItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.memories();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _forget(MemoryItem m) async {
    setState(() => _items = _items!.where((x) => x.id != m.id).toList());
    try {
      await _repo.deleteMemory(m.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      _say(e.message);
      _load();
    }
  }

  Future<void> _togglePrivate(MemoryItem m) async {
    try {
      await _repo.setMemoryPrivate(m.id, !m.sensitive);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  Widget _card(MemoryItem m) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(18, 14, 6, 8),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.content, style: G.text(19, height: 1.28)),
                const SizedBox(height: 5),
                Text(
                  [
                    m.saidByYou ? 'You said this on ${DateFormat('d MMM').format(m.createdAt)}' : 'Noticed on ${DateFormat('d MMM').format(m.createdAt)}',
                    if (m.sensitive) 'private',
                  ].join(' · '),
                  style: G.text(15, color: m.sensitive ? G.accent : G.muted, height: 1.25),
                ),
              ]),
            ),
          ),
          IconButton(
            tooltip: m.sensitive ? 'Private: Ally will not bring this up' : 'Make private',
            onPressed: () => _togglePrivate(m),
            icon: Icon(m.sensitive ? Icons.lock_rounded : Icons.lock_open_rounded, size: 20, color: m.sensitive ? G.accent : G.muted),
          ),
          IconButton(
            tooltip: 'Forget this',
            onPressed: () => _forget(m),
            icon: Icon(Icons.close_rounded, size: 20, color: G.muted),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final groups = <String, List<MemoryItem>>{};
    for (final m in items ?? const <MemoryItem>[]) {
      groups.putIfAbsent(m.kind, () => []).add(m);
    }
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          Text('What I know about you', style: G.text(42, w: FontWeight.w600, height: 1.05, letterSpacing: -1.2)),
          const SizedBox(height: 10),
          Text("Change or remove anything. It's yours. Private things only come up if you raise them.", style: G.text(18, color: G.muted, height: 1.35)),
          const SizedBox(height: 18),
          if (_error != null) Text(_error!, style: G.text(17, color: G.muted, height: 1.4)),
          if (items == null && _error == null) Text('Loading…', style: G.text(18, color: G.muted)),
          if (items != null && items.isEmpty) Text('Nothing yet. Talk to Ally and it will start to learn.', style: G.text(19, height: 1.35)),
          for (final kind in _kindLabel.keys)
            if (groups[kind]?.isNotEmpty ?? false) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(_kindLabel[kind]!, style: G.text(16, color: G.muted, height: 1.2)),
              ),
              for (final m in groups[kind]!) _card(m),
            ],
        ],
      ),
    );
  }
}
