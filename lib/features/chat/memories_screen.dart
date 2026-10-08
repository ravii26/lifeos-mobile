import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

const _kindLabel = {
  'FACT': 'About you',
  'PREFERENCE': 'Preferences',
  'GOAL': 'Goals',
  'STRUGGLE': 'Struggles',
  'FEELING': 'How you felt',
  'PERSON': 'People',
  'EVENT': 'What happened',
};

/// Everything the assistant remembers from chat, grouped, each deletable.
/// Trust needs this: nothing is remembered that you can't see or remove.
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
      setState(() => _items = items);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _forget(MemoryItem m) async {
    setState(() => _items = _items!.where((x) => x.id != m.id).toList());
    try {
      await _repo.deleteMemory(m.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  Future<void> _togglePrivate(MemoryItem m) async {
    try {
      await _repo.setMemoryPrivate(m.id, !m.sensitive);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final groups = <String, List<MemoryItem>>{};
    for (final m in items ?? const <MemoryItem>[]) {
      groups.putIfAbsent(m.kind, () => []).add(m);
    }
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(
        backgroundColor: G.bg,
        surfaceTintColor: G.bg,
        foregroundColor: G.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Text('What I remember about you', style: G.display(30)),
          const SizedBox(height: 8),
          Text("I keep these so you never have to repeat yourself. Remove anything you don't want me to know.",
              style: G.voice(17)),
          const SizedBox(height: 20),
          if (_error != null) Text(_error!, style: G.text(15, color: G.muted)),
          if (items == null && _error == null)
            Center(child: CircularProgressIndicator(color: G.ink, strokeWidth: 2)),
          if (items != null && items.isEmpty)
            Text('Nothing yet. Tell me about your day, your goals, or your schedule in chat.',
                style: G.text(16, color: G.muted)),
          for (final kind in _kindLabel.keys)
            if (groups[kind] != null) ...[
              const SizedBox(height: 14),
              Text(_kindLabel[kind]!.toUpperCase(), style: G.label()),
              const SizedBox(height: 8),
              for (final m in groups[kind]!)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.content, style: G.text(16, w: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(
                            '${DateFormat('d MMM').format(m.createdAt)} · ${m.saidByYou ? 'You told me' : 'I guessed this'}${m.sensitive ? ' · Private' : ''}',
                            style: G.text(12, color: G.muted)),
                      ]),
                    ),
                    IconButton(
                      tooltip: m.sensitive ? 'Private: I only bring it up if you do. Tap to make it normal' : 'Make private: I only bring it up if you do',
                      onPressed: () => _togglePrivate(m),
                      icon: Icon(m.sensitive ? Icons.lock_rounded : Icons.lock_open_rounded, size: 20, color: G.muted),
                    ),
                    IconButton(
                      tooltip: 'Forget this',
                      onPressed: () => _forget(m),
                      icon: Icon(Icons.close_rounded, color: G.muted),
                    ),
                  ]),
                ),
            ],
        ],
      ),
    );
  }
}
