import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';
import 'note_cards.dart';

enum LifeNotes { lists, meals, people }

/// Which of the person's notes belong on each page.
bool belongsOn(LifeNotes page, Map<String, dynamic> note) {
  final collection = '${note['collection']}';
  return switch (page) {
    LifeNotes.people => collection == 'People',
    LifeNotes.meals => collection == 'Diet',
    LifeNotes.lists => '${note['template']}' == 'LIST' && collection != 'People' && collection != 'Diet',
  };
}

/// Lists, meals and people: each already works by chat, and gets one clear page here.
class LifeNotesScreen extends StatefulWidget {
  final LifeNotes page;
  const LifeNotesScreen({super.key, required this.page});

  @override
  State<LifeNotesScreen> createState() => _LifeNotesScreenState();
}

class _LifeNotesScreenState extends State<LifeNotesScreen> {
  List<Map<String, dynamic>>? _notes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await getIt<LifeRepository>().allyNotes();
      if (mounted) setState(() => _notes = all.where((n) => belongsOn(widget.page, n)).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, hint) = switch (widget.page) {
      LifeNotes.lists => ('Lists', 'Try saying "add milk to my shopping list".'),
      LifeNotes.meals => ('Meals', 'Try saying "Monday diet: oats for breakfast, dal rice for lunch".'),
      LifeNotes.people => ('People', "Try saying \"Mummy's birthday is 12 March\"."),
    };
    final notes = _notes;
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          children: [
            Text(title, style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
            const SizedBox(height: 18),
            if (_error != null) Text(_error!, style: G.text(17, color: G.muted, height: 1.4)),
            if (notes == null && _error == null) Text('Loading…', style: G.text(18, color: G.muted)),
            for (final n in notes ?? const <Map<String, dynamic>>[]) SpecialNoteCard(n, onChanged: _load),
            if (notes != null && notes.isEmpty) Text(hint, style: G.text(19, color: G.muted, height: 1.4)),
            if (notes != null) ...[
              const SizedBox(height: 16),
              GPill('Tell Ally', primary: notes.isEmpty, onTap: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                talkRequest.value++;
              }),
            ],
          ],
        ),
      ),
    );
  }
}
