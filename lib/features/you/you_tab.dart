import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/notifications/agenda_sync.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../auth/bloc/auth_bloc.dart';
import '../guide/guide_style.dart' show G;
import '../more/log_screen.dart';
import '../more/reminders_check_screen.dart';
import '../more/voice_screen.dart';
import '../more/your_day_screen.dart';
import '../places/you_screen.dart';
import '../shell/life_cubit.dart';
import '../shrink/parked_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../design_preview/design_preview_screen.dart';
import '../firstrun/save_account.dart';
import '../library/library_page.dart';
import 'account_page.dart';
import 'ally_works_page.dart';
import 'appearance_page.dart';
import 'decide_screen.dart';
import 'history_page.dart';
import 'memories_page.dart';
import 'reminders_page.dart';
import 'search_page.dart';
import 'you_page.dart';

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

  /// For tests: saving a guest account.
  final Claim? claim;
  const YouTab({super.key, required this.user, this.repo, this.claim});

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

  Claim get _claim => widget.claim ?? getIt<AuthRepository>().claim;

  void _saveAccount() {
    final auth = context.read<AuthBloc?>();
    _push(YouPage(
      title: '',
      children: (themed, c) => [
        SaveAccountForm(
          claim: _claim,
          onSaved: (u) {
            Navigator.of(themed).pop();
            auth?.add(AuthUserUpdated(u));
            showAllyToast(themed, 'Saved. Sign in with ${u.email} on any phone.');
          },
        ),
      ],
    ));
  }

  /// An unsaved account cannot be signed back into, so ask first.
  Future<void> _signOut(BuildContext themed) async {
    final auth = context.read<AuthBloc?>();
    if (!widget.user.guest) {
      auth?.add(const AuthLogoutRequested());
      return;
    }
    final choice = await showAllySheet<String>(
      themed,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Save before signing out?', style: AllyType.h2(color: ctx.ac.ink)),
        const SizedBox(height: Sp.x1),
        Text('This account has no email yet, so after signing out nobody can open it again, including you.', style: AllyType.body(color: ctx.ac.muted)),
        const SizedBox(height: Sp.x4),
        AllyButton('Save my account', wide: true, onPressed: () => Navigator.of(ctx).pop('save')),
        const SizedBox(height: Sp.x2),
        AllyButton('Sign out and lose it', kind: AllyButtonKind.danger, wide: true, onPressed: () => Navigator.of(ctx).pop('out')),
      ]),
    );
    if (choice == 'save') _saveAccount();
    if (choice == 'out') auth?.add(const AuthLogoutRequested());
  }

  void _search() => _push(SearchPage(
        repo: _repo,
        onOpen: (hit) => switch (hit.kind) {
          'MEMORY' => _push(MemoriesPage(repo: _repo)),
          'TASK' => _push(TaskDetailScreen(taskId: hit.id)),
          'NOTE' => _push(LibraryPage(repo: _repo)),
          'SAVE' => _push(LibraryPage(repo: _repo, start: LibrarySection.saved)),
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
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    final things = [
      _Entry(Icons.menu_book_outlined, 'Library', 'Notes, people, saved links', () => _push(LibraryPage(repo: _repo))),
      _Entry(Icons.notifications_none_rounded, 'Reminders', 'Upcoming, and a check that they arrive',
          () => _push(RemindersPage(repo: _repo, onCheckDelivery: () => _push(const RemindersCheckScreen())))),
      _Entry(Icons.show_chart_rounded, 'Log', 'Numbers and counts you logged', () => _push(const LogScreen())),
      _Entry(Icons.pause_circle_outline_rounded, 'Parked', 'Things set aside on purpose', () => _push(const ParkedScreen())),
      _Entry(Icons.event_note_outlined, 'Plans and check-ins', 'Season, Sunday check-in, fitness and sleep plans', () => _push(YouScreen(user: widget.user))),
    ];
    final ally = [
      _Entry(Icons.auto_awesome_outlined, 'What Ally remembers', 'In your own words; private, still true, or forget', () => _push(MemoriesPage(repo: _repo))),
      _Entry(Icons.history_rounded, 'History', 'Everything Ally did, with Undo', () => _push(HistoryPage(repo: _repo))),
      _Entry(Icons.call_split_rounded, 'Help me decide', 'Two options, a suggestion, a check-in', () => _push(DecideScreen(repo: _repo))),
      _Entry(Icons.campaign_outlined, 'How much Ally speaks up', 'Normal, quieter or silent', () => _speakUp(themed)),
      _Entry(Icons.tune_rounded, 'How Ally works for you', 'What it helps with most, and how it talks', () => _push(AllyWorksPage(repo: _repo))),
      _Entry(Icons.schedule_rounded, 'Your normal day', 'Work hours, sleep, free time', () => _push(const YourDayScreen())),
      _Entry(Icons.record_voice_over_outlined, "Ally's voice", 'Spoken replies', () => _push(const VoiceScreen())),
    ];
    final account = [
      _Entry(Icons.contrast_rounded, 'Appearance', 'Theme, larger text, reduce motion', () => _push(const AppearancePage())),
      _Entry(Icons.shield_outlined, 'Account and privacy', 'What goes to AI, your data, delete', () {
        final auth = context.read<AuthBloc?>();
        _push(AccountPage(
          user: widget.user,
          repo: _repo,
          onSignOut: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            auth?.add(const AuthLogoutRequested());
          },
          onDesignPreview: () => _push(const DesignPreviewScreen()),
        ));
      }),
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
                Text(widget.user.guest ? 'NOT SAVED YET' : widget.user.email.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AllyType.eyebrow(color: c.faint)),
                const SizedBox(height: Sp.x1),
                Text(widget.user.name.trim().isEmpty ? 'You' : widget.user.name, style: AllyType.h1(color: c.ink)),
              ]),
              if (widget.user.guest)
                AllyCard(
                  strong: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Save your plan', style: AllyType.h2(color: c.ink)),
                    const SizedBox(height: Sp.x1),
                    Text('Add an email so your areas and steps are kept if you change or lose this phone.', style: AllyType.body(color: c.muted)),
                    const SizedBox(height: Sp.x3),
                    AllyButton('Save my account', onPressed: _saveAccount),
                  ]),
                ),
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
              AllyButton('Sign out', kind: AllyButtonKind.ghost, onPressed: () => _signOut(themed)),
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
