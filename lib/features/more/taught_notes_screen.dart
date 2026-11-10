import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/links/open_link.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart' show gConfirm, gFieldStyle;
import '../guide/guide_style.dart';

const _template = {'LIST': 'List', 'ROUTINE': 'Steps in order', 'PLAYBOOK': 'When this, do that', 'INFO': 'Info'};

/// Everything you taught Ally, grouped by collection. See it, fix it, remove it.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('${n['title']}', style: G.text(26, w: FontWeight.w600, height: 1.15)),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          style: G.text(18, height: 1.3),
          cursorColor: G.accent,
          decoration: gFieldStyle('', fill: G.surfaceHigh).copyWith(
            hintText: '',
            helperText: isList ? 'One per line' : null,
            helperStyle: G.text(15, color: G.muted, height: 1.3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
            child: Text('Cancel', style: G.text(17, height: 1.2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 48)),
            child: Text('Save', style: G.text(17, w: FontWeight.w600, color: G.accent, height: 1.2)),
          ),
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
    final ok = await gConfirm(
      context,
      title: 'Remove "${n['title']}"?',
      message: 'Ally will stop answering from it. You can undo this right after.',
      yes: 'Remove',
      no: 'Keep it',
    );
    if (!ok) return;
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
      appBar: gBar(),
      body: RefreshIndicator(
        color: G.accent,
        backgroundColor: G.card,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          children: [
            const GTitle('What I taught Ally', sub: 'Ally answers from these, and only these. To add one, just say it in Talk, like "my breakfasts are poha, oats, eggs".'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: G.text(16, color: G.accent, height: 1.3)),
              ),
            if (notes == null && _error == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2, color: G.accent),
                ),
              ),
            if (notes != null && notes.isEmpty)
              const GEmpty('Nothing yet. Teach Ally your breakfasts, a gym warm-up, or how a client likes things done.'),
            for (final entry in groups.entries) ...[
              GHeading(entry.key),
              for (final n in entry.value)
                GCard(
                  padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(_template['${n['template']}'] ?? '${n['template']}', style: G.text(16, color: G.accent, height: 1.2)),
                      ),
                      IconButton(tooltip: 'Edit', onPressed: () => _edit(n), icon: Icon(Icons.edit_outlined, size: 22, color: G.ink)),
                      IconButton(tooltip: 'Remove', onPressed: () => _delete(n), icon: Icon(Icons.close_rounded, size: 24, color: G.ink)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${n['title']}', style: G.text(23, w: FontWeight.w500, height: 1.2)),
                        const SizedBox(height: 8),
                        if (((n['items'] as List?) ?? const []).isNotEmpty)
                          for (var i = 0; i < (n['items'] as List).length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(n['template'] == 'ROUTINE' ? '${i + 1}.  ' : '•  ', style: G.text(17, color: G.muted, height: 1.35)),
                                Expanded(child: Text('${(n['items'] as List)[i]}', style: G.text(17, color: G.muted, height: 1.35))),
                              ]),
                            ),
                        // A video summary keeps its link as the note's text: show it as a button.
                        if (_link(n['text']) != null)
                          OpenSourceButton(_link(n['text'])!)
                        else if (n['text'] != null && '${n['text']}'.isNotEmpty)
                          Text('${n['text']}', style: G.text(17, color: G.muted, height: 1.35)),
                      ]),
                    ),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _link(Object? text) {
    final t = '${text ?? ''}'.trim();
    return RegExp(r'^https?://\S+$').hasMatch(t) ? t : null;
  }
}
