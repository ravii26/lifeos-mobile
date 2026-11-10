import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../chat/memories_screen.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';
import '../guide/save_sheet.dart';
import '../more/taught_notes_screen.dart';
import '../more/your_day_screen.dart';
import '../shell/life_cubit.dart';
import '../vault/vault_screen.dart';
import 'note_cards.dart';
import 'now_cubit.dart';

/// Notes: what you taught Ally, what you saved, and what Ally knows about you.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = getIt<LifeRepository>();
  List<Json> _saves = const [];
  List<Map<String, dynamic>> _notes = const [];
  String? _error;
  int _tab = 0; // Taught, Saved, About you
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.saves(), _repo.allyNotes()]);
      if (!mounted) return;
      setState(() {
        _saves = results[0];
        _notes = results[1];
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _push(Widget page) {
    final life = context.read<LifeCubit>();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => BlocProvider.value(value: life, child: page)))
        .then((_) => _load());
  }

  Future<void> _openSave(Json s) async {
    final changed = await openSaveSheet(context, SaveSource(existingId: '${s['id']}'));
    if (changed) placesRefresh.value++;
    _load();
  }

  Widget _noteCard(Map<String, dynamic> n, bool first) {
    final ink = first ? G.onInk : G.ink;
    final items = (n['items'] as List?) ?? const [];
    final text = '${n['text'] ?? ''}';
    final line = items.isNotEmpty ? items.take(4).join(', ') : text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: first ? G.accent : G.card,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _push(const TaughtNotesScreen()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['title']}', style: G.text(22, w: FontWeight.w600, color: ink, height: 1.2)),
              if (line.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(17, color: ink, height: 1.3)),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _rowCard({required String title, String? sub, required VoidCallback onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: G.card,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 12, 15),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: G.text(19, height: 1.25)),
                    if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: G.text(15, color: G.muted, height: 1.3))),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: G.faint),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final waiting = _saves.where((s) => s['shelved'] != true && s['later'] != true).toList();
    final queue = _saves.where((s) => s['later'] == true).toList();
    final shelf = _saves.where((s) => s['shelved'] == true).length;
    final q = _search.toLowerCase();
    final notes = q.isEmpty ? _notes : _notes.where((n) => '${n['title']} ${n['text'] ?? ''}'.toLowerCase().contains(q)).toList();
    final saves = q.isEmpty ? waiting : waiting.where((s) => '${s['title']}'.toLowerCase().contains(q)).toList();
    final nothing = _notes.isEmpty && _saves.isEmpty;
    final plain = notes.where((n) => !isSpecialNote(n)).toList();

    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
            children: [
              Text('Notes', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
              const SizedBox(height: 8),
              Text('Things you taught me, so you never have to remember.', style: G.text(19, color: G.muted, height: 1.3)),
              const SizedBox(height: 16),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: G.text(16, color: G.muted, height: 1.3))),
              if (nothing && _error == null) ...[
                GPill('Teach Ally something', primary: true, onTap: () => starterRequest.value = Starter.teach),
                const SizedBox(height: 10),
                GPill('Turn a video into action', onTap: () => starterRequest.value = Starter.video),
              ],
              if (!nothing) ...[
                Container(
                  height: 52,
                  padding: const EdgeInsets.only(left: 18, right: 8),
                  decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(26)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, size: 22, color: G.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _search = v.trim()),
                        style: G.text(17, height: 1.3),
                        cursorColor: G.accent,
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: G.text(17, color: G.faint, height: 1.3),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_search.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: Icon(Icons.close_rounded, size: 20, color: G.muted),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: _TabPill(
                        label: ['Taught', 'Saved', 'About you'][i],
                        active: _tab == i,
                        onTap: () => setState(() => _tab = i),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                ]),
                const SizedBox(height: 16),
              ],
              if (_tab == 0 && !nothing) ...[
                for (final n in notes)
                  if (isSpecialNote(n)) SpecialNoteCard(n, onChanged: _load) else _noteCard(n, identical(n, plain.firstOrNull)),
                if (notes.isEmpty) Text('Nothing matches.', style: G.text(18, color: G.muted, height: 1.3)),
                const SizedBox(height: 10),
                GPill('Teach Ally something', primary: true, onTap: () => starterRequest.value = Starter.teach),
              ],
              if (_tab == 1 && !nothing) ...[
                WatchLaterSection(items: queue, onChanged: () {
                  placesRefresh.value++;
                  _load();
                }),
                if (saves.isEmpty)
                  Text('Nothing waiting. In YouTube or Instagram, tap Share and pick Ally.', style: G.text(18, color: G.muted, height: 1.4)),
                for (final s in saves) _rowCard(title: '${s['title']}', sub: 'Decide what it is for', onTap: () => _openSave(s)),
                if (shelf > 0) _rowCard(title: 'For hard days ($shelf)', sub: 'Ally brings these back when you feel low.', onTap: () => _push(const VaultScreen())),
              ],
              if (_tab == 2 && !nothing) ...[
                _rowCard(title: 'My day', sub: 'When you wake, work and sleep', onTap: () => _push(const YourDayScreen())),
                _rowCard(title: 'What Ally remembers', sub: 'See, change or delete it', onTap: () => _push(const MemoriesScreen())),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: active ? G.accent : G.card,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            child: Text(label, style: G.text(16, w: active ? FontWeight.w600 : FontWeight.w400, color: active ? G.onInk : G.ink, height: 1.2)),
          ),
        ),
      );
}
