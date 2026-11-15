import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/notifications/agenda_sync.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../auth/bloc/auth_bloc.dart';
import '../guide/guide_style.dart' show G;
import '../more/log_screen.dart';
import '../more/reminders_check_screen.dart';
import '../more/settings_screen.dart';
import '../more/voice_screen.dart';
import '../more/your_day_screen.dart';
import '../places/life_notes_screen.dart';
import '../places/notes_screen.dart';
import '../places/you_screen.dart';
import '../shell/life_cubit.dart';
import '../shrink/parked_screen.dart';
import '../tasks/task_detail_screen.dart';
import 'ally_works_page.dart';
import 'history_page.dart';
import 'memories_page.dart';
import 'reminders_page.dart';
import 'search_page.dart';

/// One row on the You tab.
class _Entry {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _Entry(this.icon, this.title, this.sub, this.onTap);
}

/// You: everything that is not today, an area or the week. It replaces My
/// life; every place My life reached is still here. Pages not rebuilt yet
/// open in the earlier look.
class YouTab extends StatefulWidget {
  final AppUser user;

  /// For tests.
  final LifeRepository? repo;
  const YouTab({super.key, required this.user, this.repo});

  @override
  State<YouTab> createState() => _YouTabState();
}

class _YouTabState extends State<YouTab> {
  late final LifeRepository _repo = widget.repo ?? getIt<LifeRepository>();

  /// Opens an earlier-look page with what it reads from above.
  void _push(Widget page, {String? title}) {
    final life = context.read<LifeCubit?>();
    Widget body = title == null
        ? page
        : Scaffold(
            backgroundColor: G.bg,
            appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0, title: Text(title)),
            body: page,
          );
    if (life != null) body = BlocProvider.value(value: life, child: body);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => body));
  }

  void _search() => _push(SearchPage(
        repo: _repo,
        onOpen: (hit) => switch (hit.kind) {
          'MEMORY' => _push(MemoriesPage(repo: _repo)),
          'TASK' => _push(TaskDetailScreen(taskId: hit.id)),
          'NOTE' || 'SAVE' => _push(const NotesScreen(), title: ''),
          _ => null,
        },
      ));

  static String _levelWords(String l) => switch (l) {
        'QUIETER' => 'Quieter: a morning briefing, an evening wrap-up and the Sunday review',
        'SILENT' => 'Silent: only the reminders you set',
        _ => 'Normal: briefing, nudges for what you planned, follow-ups, wrap-up',
      };

  Future<void> _speakUp(BuildContext themed) async {
    String current = 'NORMAL';
    try {
      current = await _repo.proactivity();
    } on ApiException {
      // Shown as Normal; the choice still saves when the server answers.
    }
    if (!themed.mounted) return;
    final picked = await showAllySheet<String>(
      themed,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('How much should Ally speak up?', style: AllyType.h2(color: ctx.ac.ink)),
        const SizedBox(height: Sp.x1),
        Text('Never during your night. Reminders you set always come.', style: AllyType.body(color: ctx.ac.muted)),
        const SizedBox(height: Sp.x4),
        for (final l in const ['NORMAL', 'QUIETER', 'SILENT']) ...[
          AllyCard(
            strong: l == current,
            onTap: () => Navigator.of(ctx).pop(l),
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_levelWords(l).split(':').first, style: AllyType.body(color: ctx.ac.ink, w: FontWeight.w600)),
              Text(_levelWords(l).split(': ').last, style: AllyType.small(color: ctx.ac.muted)),
            ]),
          ),
          const SizedBox(height: Sp.x2),
        ],
      ]),
    );
    if (picked == null || picked == current || !themed.mounted) return;
    try {
      await _repo.setProactivity(picked);
      await AgendaSync.now();
      if (themed.mounted) {
        showAllyToast(themed, '${_levelWords(picked).split(':').first} from now on.', onUndo: () async {
          try {
            await _repo.setProactivity(current);
            await AgendaSync.now();
          } catch (_) {}
        });
      }
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyTheme.dark(), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final things = [
      _Entry(Icons.sticky_note_2_outlined, 'Notes', 'Notes and saved videos', () => _push(const NotesScreen(), title: '')),
      _Entry(Icons.checklist_rounded, 'Lists', 'Packing, shopping, anything with ticks', () => _push(const LifeNotesScreen(page: LifeNotes.lists))),
      _Entry(Icons.restaurant_outlined, 'Meals', 'What you plan to eat', () => _push(const LifeNotesScreen(page: LifeNotes.meals))),
      _Entry(Icons.people_outline_rounded, 'People', 'What they told you, when you last spoke', () => _push(const LifeNotesScreen(page: LifeNotes.people))),
      _Entry(Icons.notifications_none_rounded, 'Reminders', 'Upcoming, and a check that they arrive',
          () => _push(RemindersPage(repo: _repo, onCheckDelivery: () => _push(const RemindersCheckScreen())))),
      _Entry(Icons.show_chart_rounded, 'Log', 'Numbers and counts you logged', () => _push(const LogScreen())),
      _Entry(Icons.pause_circle_outline_rounded, 'Parked', 'Things set aside on purpose', () => _push(const ParkedScreen())),
      _Entry(Icons.event_note_outlined, 'Plans and check-ins', 'Season, Sunday check-in, fitness and sleep plans', () => _push(YouScreen(user: widget.user))),
    ];
    final ally = [
      _Entry(Icons.auto_awesome_outlined, 'What Ally remembers', 'In your own words; private, still true, or forget', () => _push(MemoriesPage(repo: _repo))),
      _Entry(Icons.history_rounded, 'History', 'Everything Ally did, with Undo', () => _push(HistoryPage(repo: _repo))),
      _Entry(Icons.campaign_outlined, 'How much Ally speaks up', 'Normal, quieter or silent', () => _speakUp(themed)),
      _Entry(Icons.tune_rounded, 'How Ally works for you', 'What it helps with most, and how it talks', () => _push(AllyWorksPage(repo: _repo))),
      _Entry(Icons.schedule_rounded, 'Your normal day', 'Work hours, sleep, free time', () => _push(const YourDayScreen())),
      _Entry(Icons.record_voice_over_outlined, "Ally's voice", 'Spoken replies', () => _push(const VoiceScreen())),
    ];
    final account = [
      _Entry(Icons.shield_outlined, 'Account and your data', 'Download, delete, and the design preview', () => _push(SettingsScreen(user: widget.user))),
    ];
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x4, Sp.side, Sp.x6),
          children: [
            Stagger(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.user.email.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AllyType.eyebrow(color: c.faint)),
                const SizedBox(height: Sp.x1),
                Text(widget.user.name.trim().isEmpty ? 'You' : widget.user.name, style: AllyType.h1(color: c.ink)),
              ]),
              Pressable(
                onTap: _search,
                semanticLabel: 'Search',
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Rad.button), border: Border.all(color: c.line)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: c.faint),
                    const SizedBox(width: Sp.x3),
                    Expanded(child: Text('Search notes, to-dos, saves, goals', style: AllyType.body(color: c.faint))),
                  ]),
                ),
              ),
              _group(c, 'YOUR THINGS', things),
              _group(c, 'ALLY', ally),
              _group(c, 'ACCOUNT', account),
              AllyButton('Sign out', kind: AllyButtonKind.ghost, onPressed: () => context.read<AuthBloc?>()?.add(const AuthLogoutRequested())),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _group(AllyColors c, String title, List<_Entry> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        AllyCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x1),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(color: c.line, height: 1),
              Pressable(
                scale: 0.985,
                onTap: rows[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(12)),
                      child: Icon(rows[i].icon, color: c.muted, size: 20),
                    ),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(rows[i].title, style: AllyType.body(color: c.ink, w: FontWeight.w500)),
                        Text(rows[i].sub, style: AllyType.small(color: c.faint)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.faint),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ]);
}
