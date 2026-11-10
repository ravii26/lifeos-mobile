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
            if (widget.page == LifeNotes.people && notes != null)
              if (quietPerson(notes, DateTime.now()) case final quiet?) _WhileCard(quiet, onChanged: _load),
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

/// "It's been a while": the one person you have gone longest without speaking to.
class _WhileCard extends StatelessWidget {
  final Map<String, dynamic> person;
  final VoidCallback onChanged;
  const _WhileCard(this.person, {required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final last = lastContactOf(person)!;
    final hasPhone = phoneOf(person) != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(30)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("It's been a while", style: G.text(16, color: G.onInk, height: 1.2)),
        const SizedBox(height: 6),
        Text('${person['title']}', style: G.text(34, w: FontWeight.w600, color: G.onInk, height: 1.1, letterSpacing: -0.8)),
        const SizedBox(height: 6),
        Text('You last spoke ${agoText(last, DateTime.now())}.', style: G.text(18, color: G.onInk, height: 1.35)),
        if (hasPhone) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GPill('Call', primary: true, onTap: () => contactPerson(context, person, whatsApp: false, then: onChanged))),
            const SizedBox(width: 8),
            Expanded(child: GPill('WhatsApp', onTap: () => contactPerson(context, person, whatsApp: true, then: onChanged))),
          ]),
        ],
      ]),
    );
  }
}
