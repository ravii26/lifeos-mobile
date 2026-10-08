import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

const _template = {'LIST': 'List', 'ROUTINE': 'Steps in order', 'PLAYBOOK': 'When X, do Y', 'INFO': 'Info'};

/// Everything you taught Ally, grouped by collection. See it, fix it, remove
/// it. Ally answers from these notes and only these, so they should be right.
class TaughtNotesScreen extends StatefulWidget {
  const TaughtNotesScreen({super.key});

  @override
  State<TaughtNotesScreen> createState() => _TaughtNotesScreenState();
}

class _TaughtNotesScreenState extends State<TaughtNotesScreen> {
  final _repo = getIt<LifeRepository>();
  List<Map<String, dynamic>>? _notes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await _repo.allyNotes();
      if (!mounted) return;
      setState(() => _notes = notes);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _say(String text, {String? undoId}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      action: undoId == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await _repo.undo(undoId);
                  await _load();
                } on ApiException catch (e) {
                  _say(e.message);
                }
              }),
    ));
  }

  Future<void> _edit(Map<String, dynamic> n) async {
    final isList = n['template'] == 'LIST' || n['template'] == 'ROUTINE';
    final items = ((n['items'] as List?) ?? const []).map((e) => '$e').toList();
    final c = TextEditingController(text: isList ? items.join('\n') : '${n['text'] ?? ''}');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${n['title']}', style: G.text(17, w: FontWeight.w700)),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          style: G.text(16),
          decoration: InputDecoration(helperText: isList ? 'One per line' : null),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (saved == null) return;
    try {
      final undo = isList
          ? await _repo.updateAllyNote('${n['id']}',
              items: saved.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList())
          : await _repo.updateAllyNote('${n['id']}', text: saved.trim());
      await _load();
      _say('Saved', undoId: undo);
    } on ApiException catch (e) {
      _say(e.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${n['title']}"?', style: G.text(17, w: FontWeight.w700)),
        content: Text("Ally will stop answering from it. You can undo this right after.", style: G.text(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final undo = await _repo.deleteAllyNote('${n['id']}');
      await _load();
      _say('Removed', undoId: undo);
    } on ApiException catch (e) {
      _say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final n in notes ?? const <Map<String, dynamic>>[]) {
      groups.putIfAbsent('${n['collection']}', () => []).add(n);
    }
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Text('Notes you taught Ally', style: G.display(30)),
          const SizedBox(height: 8),
          Text('I answer from these, and only these. To add one, tell me in chat, like "my breakfasts are poha, oats, eggs".',
              style: G.voice(17)),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: G.text(15, color: G.muted)),
          if (notes == null && _error == null)
            const Center(child: CircularProgressIndicator(color: G.ink, strokeWidth: 2)),
          if (notes != null && notes.isEmpty)
            Text('Nothing yet. Teach me your breakfasts, a gym warm-up, or how a client likes things done.',
                style: G.text(16, color: G.muted)),
          for (final entry in groups.entries) ...[
            const SizedBox(height: 10),
            Text(entry.key, style: G.text(18, w: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final n in entry.value)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(16)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${n['title']}', style: G.text(16, w: FontWeight.w600)),
                      Text(_template['${n['template']}'] ?? '', style: G.text(12, color: G.muted)),
                      const SizedBox(height: 6),
                      if (((n['items'] as List?) ?? const []).isNotEmpty)
                        for (var i = 0; i < (n['items'] as List).length; i++)
                          Text(n['template'] == 'ROUTINE' ? '${i + 1}. ${(n['items'] as List)[i]}' : '· ${(n['items'] as List)[i]}',
                              style: G.text(15)),
                      if (n['text'] != null && '${n['text']}'.isNotEmpty) Text('${n['text']}', style: G.text(15)),
                    ]),
                  ),
                  IconButton(
                      tooltip: 'Edit',
                      onPressed: () => _edit(n),
                      icon: const Icon(Icons.edit_outlined, size: 20, color: G.muted)),
                  IconButton(
                      tooltip: 'Remove',
                      onPressed: () => _delete(n),
                      icon: const Icon(Icons.close_rounded, color: G.muted)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}
