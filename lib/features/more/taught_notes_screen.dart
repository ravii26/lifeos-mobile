import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

const _template = {'LIST': 'List', 'ROUTINE': 'Steps in order', 'PLAYBOOK': 'When X, do Y', 'INFO': 'Info'};

/// Everything you taught Ally, grouped by collection. See it, fix it, remove it.
/// Styled according to Nocturne Sanctuary (ally_notes_saves).
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
              textColor: G.accent,
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
        backgroundColor: G.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        title: Text('${n['title']}', style: G.text(16, w: FontWeight.w600)),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          style: G.text(14),
          cursorColor: G.accent,
          decoration: InputDecoration(
            helperText: isList ? 'One per line' : null,
            helperStyle: G.label(size: 11, color: G.faint),
            filled: true,
            fillColor: G.inset,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: G.lineSoft, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: G.lineSoft, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: G.accent, width: 1)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: G.label(size: 12, color: G.faint))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('Save', style: G.label(size: 12, color: G.accent, w: FontWeight.w600))),
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
        backgroundColor: G.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        title: Text('Remove "${n['title']}"?', style: G.text(16, w: FontWeight.w600)),
        content: Text("Ally will stop answering from it. You can undo this right after.", style: G.text(13.5, color: G.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep it', style: G.label(size: 12, color: G.faint))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remove', style: G.label(size: 12, color: Colors.redAccent, w: FontWeight.w600))),
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
      appBar: GTopBar(
        'Taught Notes',
        subtitle: 'What you taught Ally to answer from',
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Text(
              'Ally answers from these, and only these. To add one, tell Ally in chat, like "my breakfasts are poha, oats, eggs".',
              style: G.voice(14, color: G.muted),
            ),
            const SizedBox(height: 14),
            Container(height: 0.5, color: G.lineSoft),
            const SizedBox(height: 14),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: G.label(size: 12, color: Colors.redAccent)),
              ),
            if (notes == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            if (notes != null && notes.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Nothing yet. Teach Ally your breakfasts, a gym warm-up, or how a client likes things done.',
                  style: G.voice(14, color: G.muted),
                ),
              ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(entry.key.toUpperCase(), style: G.label(size: 10, color: G.faint, w: FontWeight.w600)),
              ),
              for (final n in entry.value)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: G.card,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: G.inset,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'TEMPLATE: ${_template['${n['template']}'] ?? '${n['template']}'}'.toUpperCase(),
                          style: G.label(size: 9.5, color: G.accent, w: FontWeight.w600),
                        ),
                      ),
                      Row(children: [
                        IconButton(
                          tooltip: 'Edit',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _edit(n),
                          icon: Icon(Icons.edit_outlined, size: 16, color: G.faint),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Remove',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _delete(n),
                          icon: Icon(Icons.close_rounded, size: 16, color: G.faint),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 6),
                    Text('${n['title']}', style: G.text(15, w: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (((n['items'] as List?) ?? const []).isNotEmpty)
                      for (var i = 0; i < (n['items'] as List).length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n['template'] == 'ROUTINE' ? '${i + 1}. ' : '• ',
                                style: G.label(size: 12, color: G.faint)),
                            Expanded(child: Text('${(n['items'] as List)[i]}', style: G.text(13, color: G.muted))),
                          ]),
                        ),
                    if (n['text'] != null && '${n['text']}'.isNotEmpty)
                      Text('${n['text']}', style: G.text(13, color: G.muted)),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
