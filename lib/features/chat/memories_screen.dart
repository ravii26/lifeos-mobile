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
/// Nocturne Sanctuary bedside pattern: trust through visible and erasable memory.
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  Future<void> _togglePrivate(MemoryItem m) async {
    try {
      await _repo.setMemoryPrivate(m.id, !m.sensitive);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
      appBar: const GTopBar(
        'Memories',
        subtitle: 'What Ally holds for you',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: G.inset,
              border: Border.all(color: G.lineSoft, width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: G.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kept so you never have to repeat yourself. Private items are never surfaced unless you bring them up first.',
                    style: G.voice(13.5, color: G.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(_error!, style: G.text(14, color: G.carried)),
            ),
          if (items == null && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                  child: CircularProgressIndicator(
                      color: G.accent, strokeWidth: 1.5)),
            ),
          if (items != null && items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'Nothing stored yet.\nTalk to Ally in chat to teach your preferences and rhythms.',
                  textAlign: TextAlign.center,
                  style: G.voice(14.5, color: G.muted),
                ),
              ),
            ),
          for (final kind in _kindLabel.keys)
            if (groups[kind] != null && groups[kind]!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  _kindLabel[kind]!.toUpperCase(),
                  style: G.label(size: 11, color: G.faint),
                ),
              ),
              for (final m in groups[kind]!)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: G.card,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 36,
                        margin: const EdgeInsets.only(top: 2, right: 12),
                        decoration: BoxDecoration(
                          color: m.sensitive
                              ? G.carried
                              : (m.saidByYou ? G.accent : G.good),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.content,
                              style: G.text(14.5,
                                  w: FontWeight.w400, color: G.ink),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  DateFormat('d MMM').format(m.createdAt),
                                  style: G.label(size: 11, color: G.faint),
                                ),
                                Text(' · ',
                                    style: G.label(size: 11, color: G.faint)),
                                Text(
                                  m.saidByYou ? 'Told by you' : 'Inferred',
                                  style: G.label(size: 11, color: G.muted),
                                ),
                                if (m.sensitive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: G.carried.withValues(alpha: 0.15),
                                      border: Border.all(
                                          color:
                                              G.carried.withValues(alpha: 0.4),
                                          width: 0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      'Private',
                                      style: G.label(
                                          size: 10, color: G.carried),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: m.sensitive
                            ? 'Private: Ally will not volunteer this'
                            : 'Make private',
                        onPressed: () => _togglePrivate(m),
                        icon: Icon(
                          m.sensitive
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 17,
                          color: m.sensitive ? G.carried : G.faint,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        tooltip: 'Forget this',
                        onPressed: () => _forget(m),
                        icon: Icon(Icons.close_rounded,
                            size: 17, color: G.faint),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
