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
import 'now_cubit.dart';

/// Notes screen: what you taught Ally, what you saved, and what Ally knows about you.
/// Styled according to Nocturne Sanctuary (ally_notes_saves design specification).
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
  int _tab = 0; // 0: Taught to Ally, 1: Saves & Reels, 2: About You
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

  @override
  Widget build(BuildContext context) {
    final waiting = _saves.where((s) => s['shelved'] != true).toList();
    final shelf = _saves.where((s) => s['shelved'] == true).length;
    final filteredNotes = _search.isEmpty
        ? _notes
        : _notes.where((n) => '${n['title']} ${n['text'] ?? ''}'.toLowerCase().contains(_search.toLowerCase())).toList();
    // Nothing taught or saved yet: one sentence and the ways to start.
    final nothing = _notes.isEmpty && _saves.isEmpty;
    final filteredSaves = _search.isEmpty
        ? waiting
        : waiting.where((s) => '${s['title']}'.toLowerCase().contains(_search.toLowerCase())).toList();

    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              // Top Bar
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(Icons.bedtime_outlined, size: 20, color: G.accent),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Notes', style: G.voice(16, color: G.ink)),
                    Text('What you taught Ally and what you saved', style: G.label(size: 11, color: G.faint)),
                  ]),
                ]),
              ]),
              const SizedBox(height: 12),

              if (nothing && _error == null) _EmptyNotes(onTeach: () => starterRequest.value = Starter.teach),
              // Search, once there is something to search
              if (!nothing) Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: G.inset,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 18, color: G.faint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v.trim()),
                      style: G.text(13.5),
                      cursorColor: G.accent,
                      decoration: InputDecoration(
                        hintText: 'Search notes, summaries, memories…',
                        hintStyle: G.label(size: 12, color: G.faint),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_search.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      child: Icon(Icons.close_rounded, size: 16, color: G.faint),
                    ),
                ]),
              ),
              if (!nothing) const SizedBox(height: 12),

              // Segment Filter Tabs
              if (!nothing) SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _TabPill(
                    label: 'Taught (${_notes.length})',
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  _TabPill(
                    label: 'Saved (${waiting.length})',
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 8),
                  _TabPill(
                    label: 'About you',
                    active: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: G.label(size: 12, color: Colors.redAccent)),
                ),

              // TAB 0: Taught to Ally
              if (_tab == 0 && !nothing) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Things you taught Ally', style: G.text(16, w: FontWeight.w600)),
                ]),
                const SizedBox(height: 2),
                Text(
                  "Ally answers from these, so you don't have to repeat yourself.",
                  style: G.label(size: 12, color: G.faint),
                ),
                const SizedBox(height: 12),
                if (filteredNotes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Nothing taught yet. Tell Ally things like your breakfast options or your gym routine.',
                      style: G.voice(14, color: G.muted),
                    ),
                  ),
                for (final n in filteredNotes)
                  InkWell(
                    onTap: () => _push(const TaughtNotesScreen()),
                    child: Container(
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
                              _kindName['${n['template']}'] ?? 'Note',
                              style: G.label(size: 10, color: G.faint, w: FontWeight.w600),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text('${n['title']}', style: G.text(15, w: FontWeight.w600)),
                        if (n['items'] != null && (n['items'] as List).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          for (final it in (n['items'] as List).take(3))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: G.faint)),
                                const SizedBox(width: 6),
                                Expanded(child: Text('$it', style: G.text(13, color: G.muted))),
                              ]),
                            ),
                        ] else if (n['text'] != null && '${n['text']}'.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${n['text']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(13, color: G.muted)),
                        ],
                      ]),
                    ),
                  ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => starterRequest.value = Starter.teach,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: G.accent,
                    side: BorderSide(color: G.accent.withValues(alpha: 0.4), width: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(Icons.add_rounded, size: 18, color: G.accent),
                  label: Text('Teach Ally something new', style: G.label(size: 11, color: G.accent, w: FontWeight.w600)),
                ),
              ],

              // TAB 1: Saves & Reels
              if (_tab == 1 && !nothing) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Saved videos and links', style: G.text(16, w: FontWeight.w600)),
                ]),
                const SizedBox(height: 2),
                Text(
                  'Pick what each one is for: something to do, or something for a low day.',
                  style: G.label(size: 12, color: G.faint),
                ),
                const SizedBox(height: 12),
                if (filteredSaves.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Nothing saved. In YouTube or Instagram, tap Share and pick Ally.',
                      style: G.voice(14, color: G.muted),
                    ),
                  ),
                for (final s in filteredSaves)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Icon(Icons.play_circle_outline_rounded, size: 16, color: G.carried),
                          const SizedBox(width: 6),
                          Text('Saved link', style: G.label(size: 11, color: G.faint)),
                        ]),
                      ]),
                      const SizedBox(height: 8),
                      Text('${s['title']}', style: G.text(15, w: FontWeight.w600, height: 1.3)),
                      const SizedBox(height: 10),
                      const SizedBox(height: 8),
                      Row(children: [
                        TextButton(
                          onPressed: () => _openSave(s),
                          style: TextButton.styleFrom(
                            backgroundColor: G.surfaceHigh,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          ),
                          child: Text('Decide what it is for', style: G.label(size: 11, color: G.accent, w: FontWeight.w600)),
                        ),
                      ]),
                    ]),
                  ),

                // For hard days: only when something is on it.
                if (shelf > 0) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _push(const VaultScreen()),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: G.card,
                        border: Border.all(color: G.lineSoft, width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(children: [
                        Icon(Icons.spa_outlined, size: 18, color: G.carried),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('For hard days ($shelf)', style: G.text(14, w: FontWeight.w500)),
                            Text('Ally brings these back when you say you feel low.', style: G.text(12.5, color: G.muted)),
                          ]),
                        ),
                        Icon(Icons.chevron_right_rounded, color: G.faint),
                      ]),
                    ),
                  ),
                ],
              ],

              // TAB 2: About You
              if (_tab == 2 && !nothing) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('About you', style: G.text(16, w: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                _AboutCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'Your day',
                  sub: 'When you wake, work and sleep, so Ally suggests things at the right time',
                  onTap: () => _push(const YourDayScreen()),
                ),
                const SizedBox(height: 10),
                _AboutCard(
                  icon: Icons.psychology_outlined,
                  title: 'What Ally remembers',
                  sub: 'Things you told Ally about yourself. See them, change them, or delete them',
                  onTap: () => _push(const MemoriesScreen()),
                ),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? G.surfaceHigh : G.card,
            border: Border.all(color: active ? G.accent.withValues(alpha: 0.5) : G.lineSoft, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: G.label(
              size: 11,
              color: active ? G.accent : G.faint,
              w: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
}

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _AboutCard({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: G.card,
            border: Border.all(color: G.lineSoft, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: G.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: G.text(15, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(sub, style: G.text(13, color: G.muted, height: 1.4)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: G.faint),
          ]),
        ),
      );
}

const _kindName = {'LIST': 'List', 'ROUTINE': 'Routine', 'PLAYBOOK': 'How-to', 'INFO': 'Info'};

/// Notes with nothing in it yet: what it is for, and the two ways to fill it.
class _EmptyNotes extends StatelessWidget {
  final VoidCallback onTeach;
  const _EmptyNotes({required this.onTeach});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nothing here yet.', style: G.voice(20, color: G.ink)),
          const SizedBox(height: 6),
          Text(
              'Teach Ally things it should know, like your breakfast options or a gym routine. '
              'Or turn a video you saved into something to do.',
              style: G.text(14, color: G.muted, height: 1.45)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onTeach,
            style: FilledButton.styleFrom(
              backgroundColor: G.accent,
              foregroundColor: G.bg,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text('Teach Ally something', style: G.text(15, w: FontWeight.w600, color: G.bg)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => starterRequest.value = Starter.video,
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: Icon(Icons.play_circle_outline_rounded, size: 18, color: G.accent),
            label: Text('Turn a video into action', style: G.text(15, w: FontWeight.w600, color: G.accent)),
          ),
        ]),
      );
}
