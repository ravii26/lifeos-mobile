import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/notifications/agenda_sync.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../areas/areas_screen.dart';
import '../auth/bloc/auth_bloc.dart';
import '../chat/memories_screen.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';
import '../habits/habits_screen.dart';
import '../more/how_ally_works_screen.dart';
import '../more/voice_screen.dart';
import '../more/reminders_check_screen.dart';
import '../more/settings_screen.dart';
import '../more/log_screen.dart';
import '../more/your_day_screen.dart';
import '../more/where_you_stand_screen.dart';
import '../shell/life_cubit.dart';
import '../shrink/parked_screen.dart';
import '../shrink/shrink_screen.dart';
import '../season/season_setup_screen.dart';
import '../season/season_review_screen.dart';
import '../sleep/sleep_setup_screen.dart';
import '../weekplan/fitness_setup_screen.dart';
import '../weekplan/checkin_screen.dart';
import '../../data/models/fitness_plan.dart';
import '../../data/models/season.dart';
import '../../data/models/sleep_plan.dart';
import 'life_notes_screen.dart';
import 'notes_screen.dart';
import 'now_cubit.dart';
import 'plan_screen.dart';
import 'week_screen.dart';

/// The goals shown in focus: active ones only, three at most.
List<Map<String, dynamic>> focusGoals(List<Map<String, dynamic>> projects) =>
    projects.where((p) => p['status'] != 'PAUSED').take(3).toList();

/// How far along a goal is, 0 to 1, when the server knows.
double? goalProgress(Map<String, dynamic> project) {
  final detail = project['detail'];
  if (detail is! Map) return null;
  final percent = detail['percent'];
  return percent is num ? (percent / 100).clamp(0.0, 1.0).toDouble() : null;
}

/// Nothing in the person's life yet: no goals, parts of life, to-dos or habits, nothing done.
bool lifeIsEmpty({required List<Map<String, dynamic>> projects, required LifeState life, required int kept}) =>
    life.status == LoadStatus.ready &&
    projects.isEmpty &&
    life.areas.isEmpty &&
    life.tasks.isEmpty &&
    life.habits.isEmpty &&
    kept == 0;

/// My life: this week's mood of the calendar, what's in focus, and everything else one tap away.
class YouScreen extends StatefulWidget {
  final AppUser user;
  const YouScreen({super.key, required this.user});

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen> {
  final _repo = getIt<LifeRepository>();
  List<Map<String, dynamic>> _projects = const [];
  String _mode = 'NORMAL';
  int? _kept;
  String _level = 'NORMAL';
  String? _error;
  bool _loaded = false; // the first load has come back, so an empty life is really empty
  SeasonData? _season; // null while loading or if it failed: the card simply waits
  SleepPlan? _sleep;
  bool _sleepLoaded = false; // the sleep card only shows once we know whether a plan exists
  RunningPlan? _fitness;
  bool _fitnessLoaded = false;

  bool get _checkinDue {
    final wd = DateTime.now().weekday; // Mon = 1 … Sun = 7
    return (wd == DateTime.saturday || wd == DateTime.sunday || wd == DateTime.monday) && (_fitness != null || (_sleep != null && !_sleep!.done));
  }

  Future<void> _loadFitness() async {
    try {
      final p = await _repo.fitnessPlanRunning();
      if (mounted) {
        setState(() {
          _fitness = p;
          _fitnessLoaded = true;
        });
      }
    } catch (_) {
      // Optional card.
    }
  }

  Future<void> _openFitness() async {
    final undoId = await openFitnessSetup(context);
    if (!mounted || undoId == null) return;
    placesRefresh.value++;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Fitness plan started. Today\'s piece shows on Now.'),
      action: undoId.isEmpty ? null : SnackBarAction(label: 'Undo', onPressed: () async {
        await _repo.undo(undoId);
        placesRefresh.value++;
      }),
    ));
  }

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  // Separate from _load so a season problem never hides the rest of My life.
  Future<void> _loadSeason() async {
    try {
      final s = await _repo.season();
      if (mounted) setState(() => _season = s);
    } catch (_) {
      // Optional card: any failure (offline, an older server without /season) just leaves it out.
    }
  }

  Future<void> _loadSleep() async {
    try {
      final p = await _repo.sleepPlan();
      if (mounted) {
        setState(() {
          _sleep = p;
          _sleepLoaded = true;
        });
      }
    } catch (_) {
      // Optional card, like the season one.
    }
  }

  Future<void> _openSleep() async {
    final undoId = await openSleepSetup(context);
    if (!mounted || undoId == null) return;
    placesRefresh.value++;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Sleep plan started. Your day now uses this week\'s wake time.'),
      action: undoId.isEmpty ? null : SnackBarAction(label: 'Undo', onPressed: () async {
        await _repo.undo(undoId);
        placesRefresh.value++;
      }),
    ));
  }

  Future<void> _sleepCheckin(int days) async {
    try {
      final r = await _repo.sleepCheckin(days);
      if (!mounted) return;
      setState(() => _sleep = r.plan);
      placesRefresh.value++;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openReview() async {
    final r = await openSeasonReview(context);
    if (!mounted || r == null) return;
    placesRefresh.value++;
    final undoId = r.undoId;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r.message),
      action: undoId == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _repo.undo(undoId);
                placesRefresh.value++;
              },
            ),
    ));
  }

  Future<void> _openSeason() async {
    final editing = _season?.season != null;
    final undoId = await openSeasonSetup(context);
    if (!mounted || undoId == null) return;
    placesRefresh.value++;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(editing ? 'Season updated. Same chapter, same week.' : 'Season started. Now shows only what matters this season.'),
      action: undoId.isEmpty
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _repo.undo(undoId);
                placesRefresh.value++;
              },
            ),
    ));
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    _loadSeason();
    _loadSleep();
    _loadFitness();
    try {
      final results = await Future.wait([
        _repo.progress(),
        _repo.mode(),
        _repo.keptThisWeek(),
        _repo.proactivity(),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = results[0] as List<Map<String, dynamic>>;
        _mode = results[1] as String;
        _kept = results[2] as int;
        _level = results[3] as String;
        _error = null;
        _loaded = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _changeMode(String mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    try {
      await _repo.setMode(mode);
      placesRefresh.value++;
    } catch (_) {}
  }

  void _push(Widget page, {String? title}) {
    final life = context.read<LifeCubit>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: life,
        child: title == null ? page : _titled(title, page),
      ),
    )).then((_) => _load());
  }

  Widget _titled(String title, Widget page) => Scaffold(
        backgroundColor: G.bg,
        appBar: AppBar(
          backgroundColor: G.bg,
          surfaceTintColor: G.bg,
          foregroundColor: G.ink,
          elevation: 0,
          title: Text(title, style: G.text(20, w: FontWeight.w500, height: 1.2)),
        ),
        body: page,
      );

  static String _levelLine(String level) => switch (level) {
        'QUIETER' => 'Quieter: morning briefing, evening wrap-up and Sunday review',
        'SILENT' => 'Silent: only the reminders you set',
        _ => 'Normal: briefing, nudges for what you planned, follow-ups, wrap-up',
      };

  // Normal / Quieter / Silent (ADR 0027). Applies right away to what's scheduled.
  Future<void> _chooseLevel() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: G.inset,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(34))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How much should Ally speak up?', style: G.text(26, w: FontWeight.w600, height: 1.12)),
            const SizedBox(height: 8),
            Text('Never during your night. Reminders you set always come.', style: G.text(16, color: G.muted, height: 1.4)),
            const SizedBox(height: 10),
            for (final l in const ['NORMAL', 'QUIETER', 'SILENT'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_level == l ? Icons.radio_button_checked : Icons.radio_button_off, color: G.accent),
                title: Text(_levelLine(l).split(':').first, style: G.text(18, w: FontWeight.w500)),
                subtitle: Text(_levelLine(l).split(': ').last, style: G.text(15, color: G.muted, height: 1.3)),
                onTap: () => Navigator.pop(ctx, l),
              ),
          ]),
        ),
      ),
    );
    if (picked == null || picked == _level) return;
    setState(() => _level = picked);
    try {
      await _repo.setProactivity(picked);
      await AgendaSync.now();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openSettings() {
    final life = context.read<LifeCubit>();
    final auth = context.read<AuthBloc>();
    final rows = <Widget>[
      _SettingRow('Parts of my life', () => _push(AreasScreen(onOpenMore: () {}))),
      _SettingRow('My day', () => _push(const YourDayScreen())),
      _SettingRow('How Ally works for me', () => _push(const HowAllyWorksScreen())),
      _SettingRow('How much Ally speaks up', _chooseLevel),
      _SettingRow("Ally's voice", () => _push(const VoiceScreen())),
      _SettingRow('What Ally remembers', () => _push(const MemoriesScreen())),
      _SettingRow('Check my reminders', () => _push(const RemindersCheckScreen())),
      _SettingRow('Account and my data', () => _push(SettingsScreen(user: widget.user))),
    ];
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: life,
        child: _titled(
          'Settings',
          ListView(padding: const EdgeInsets.fromLTRB(22, 6, 22, 24), children: [
            ...rows,
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => auth.add(const AuthLogoutRequested()),
              style: TextButton.styleFrom(foregroundColor: G.muted, minimumSize: const Size(64, 48), alignment: Alignment.centerLeft),
              child: Text('Sign out', style: G.text(17, color: G.muted, height: 1.2)),
            ),
          ]),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final focus = focusGoals(_projects);
    final places = <(String, VoidCallback)>[
      ("Today's plan", () => _push(const PlanScreen(), title: '')),
      ('Reminders', () => _push(const RemindersCheckScreen())),
      ('Habits', () => _push(HabitsScreen(onOpenMore: () {}), title: 'Habits')),
      ('Notes', () => _push(const NotesScreen(), title: '')),
      ('Lists', () => _push(const LifeNotesScreen(page: LifeNotes.lists))),
      ('Meals', () => _push(const LifeNotesScreen(page: LifeNotes.meals))),
      ('People', () => _push(const LifeNotesScreen(page: LifeNotes.people))),
      ('Log and limits', () => _push(const LogScreen())),
      ('Parked', () => _push(const ParkedScreen())),
      ('My week', () => _push(const WeekScreen())),
    ];
    final empty = _loaded && lifeIsEmpty(projects: _projects, life: context.watch<LifeCubit>().state, kept: _kept ?? 0);
    final header = Row(children: [
      Expanded(child: Text('My life', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3))),
      IconButton(
        tooltip: 'Settings',
        onPressed: _openSettings,
        icon: Icon(Icons.tune_rounded, color: G.ink),
        style: IconButton.styleFrom(backgroundColor: G.card, minimumSize: const Size(46, 46)),
      ),
    ]);
    if (empty) {
      return ColoredBox(
        color: G.bg,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              children: [
                header,
                const SizedBox(height: 56),
                const AllyOrb(size: 72),
                const SizedBox(height: 26),
                Text('What matters to you?', style: G.text(40, w: FontWeight.w600, height: 1.08, letterSpacing: -1.1)),
                const SizedBox(height: 12),
                Text('Tell me one thing you want, and your life starts to fill in here.', style: G.text(20, color: G.muted, height: 1.4)),
                const SizedBox(height: 30),
                GPill('Tell Ally', primary: true, onTap: () => talkRequest.value++),
                const SizedBox(height: 10),
                GPill('Help me plan a goal', onTap: () => starterRequest.value = Starter.goal),
              ],
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            children: [
              header,
              if ((_kept ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_kept == 1 ? '1 thing done this week' : '$_kept things done this week',
                      style: G.text(18, color: G.muted, height: 1.3)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: G.text(16, color: G.muted, height: 1.3)),
                ),
              if (_season != null) ...[
                const SizedBox(height: 18),
                _SeasonCard(data: _season!, onOpen: _season!.season?.over == true ? _openReview : _openSeason, onReview: _openReview),
              ],
              // The Sunday check-in: offered Saturday to Monday when there is a plan to check in on.
              if (_checkinDue) ...[
                const SizedBox(height: 10),
                _PlanRow(
                  title: 'Sunday check-in',
                  subtitle: 'About two minutes. Next week adjusts itself.',
                  onTap: () async {
                    await openCheckin(context);
                    placesRefresh.value++;
                  },
                ),
              ],
              if (_sleepLoaded) ...[
                const SizedBox(height: 10),
                _SleepCard(plan: _sleep, onOpen: _openSleep, onCheckin: _sleepCheckin),
              ],
              if (_fitnessLoaded) ...[
                const SizedBox(height: 10),
                _PlanRow(
                  title: _fitness == null ? 'Make my fitness plan' : 'Fitness plan',
                  subtitle: _fitness == null
                      ? 'Five questions, then Ally runs a simple weekly plan with you.'
                      : '${_fitness!.title} · week ${_fitness!.week} of ${_fitness!.weeks}',
                  // The plan runs as habits, so a running plan opens them (with their days and smallest versions).
                  onTap: _fitness == null ? _openFitness : () => _push(HabitsScreen(onOpenMore: () {}), title: 'Habits'),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("How's this week?", style: G.text(17, w: FontWeight.w500, height: 1.2)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (mode, label) in const [('NORMAL', 'Normal'), ('BUSY', 'Busy'), ('SICK', 'Sick'), ('TRAVEL', 'Away')]) ...[
                      Expanded(child: _ModePill(label: label, active: _mode == mode, onTap: () => _changeMode(mode))),
                      if (mode != 'TRAVEL') const SizedBox(width: 6),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Text('In focus', style: G.text(16, color: G.muted, height: 1.2)),
              const SizedBox(height: 8),
              if (focus.isEmpty)
                GPill('Plan a goal', onTap: () => starterRequest.value = Starter.goal)
              else
                for (final p in focus)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _GoalCard(project: p, onTap: () => _push(const WhereYouStandScreen())),
                  ),
              const SizedBox(height: 6),
              GPill('Too much on my plate', onTap: () => openShrink(context)),
              const SizedBox(height: 18),
              Text('Everything else', style: G.text(16, color: G.muted, height: 1.2)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.1,
                children: [
                  for (final (label, onTap) in places)
                    Material(
                      color: G.card,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: onTap,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: G.text(17, height: 1.2)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModePill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: active ? G.accent : G.surfaceHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: G.text(16, w: active ? FontWeight.w600 : FontWeight.w400, color: active ? G.onInk : G.ink, height: 1.2)),
            ),
          ),
        ),
      );
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback onTap;
  const _GoalCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = G.onInk;
    final message = '${project['message'] ?? ''}';
    final progress = goalProgress(project);
    return Material(
      color: G.accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${project['title']}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(20, w: FontWeight.w600, color: ink, height: 1.2)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(15, color: ink, height: 1.3)),
            ],
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: ink.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(ink),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _SettingRow(this.title, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.lineSoft))),
          child: Row(children: [
            Expanded(child: Text(title, style: G.text(18, height: 1.25))),
            Icon(Icons.chevron_right_rounded, color: G.faint),
          ]),
        ),
      );
}

/// Area tiers in plain words (doc 17).
String tierName(String tier) => switch (tier) {
      'MAIN' => 'Most important',
      'SECONDARY' => 'Important',
      'MAINTAIN' => 'Keep going',
      'LATER' => 'Later',
      _ => tier,
    };

/// The current season at the top of My life (decisions log #7): which chapter
/// this is, what has the focus, what is kept going, what waits. Before the
/// first season it offers to set one up.
class _SeasonCard extends StatelessWidget {
  final SeasonData data;
  final VoidCallback onOpen;
  final VoidCallback onReview;
  const _SeasonCard({required this.data, required this.onOpen, required this.onReview});

  // The example uses one of this person's own areas that isn't in focus yet.
  String get _hint {
    final other = [...data.keepGoing, ...data.background, ...data.parked];
    if (other.isEmpty) return 'Tap to change.';
    final name = other.first.name.split(RegExp(r'[:(]')).first.trim();
    return 'Tap to change. Or say "make $name my focus" in Talk.';
  }

  Widget _line(String label, List<SeasonPlaceItem> items, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(label, style: G.text(14, color: color ?? G.muted, height: 1.35))),
          Expanded(child: Text(items.map((i) => i.name).join(' · '), style: G.text(15, color: color ?? G.ink, height: 1.35))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = data.season;
    if (s == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Too much at once?', style: G.text(22, w: FontWeight.w600, color: G.onInk, height: 1.15)),
          const SizedBox(height: 6),
          Text("Pick this season's 2 focus areas. Everything else waits, safely saved.", style: G.text(16, color: G.onInk, height: 1.35)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(backgroundColor: G.onInk, foregroundColor: G.ink, padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
              child: Text('Set up a season', style: G.text(17, w: FontWeight.w600)),
            ),
          ),
        ]),
      );
    }
    return Material(
      color: G.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.title, style: G.text(21, w: FontWeight.w600, height: 1.15))),
              Text(s.over ? 'time to review' : 'week ${s.week} of ${s.weeks}', style: G.text(14, color: s.over ? G.accent : G.muted)),
            ]),
            if ((s.endEvent ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text('Ends ${s.endEvent}, or after ${s.weeks} weeks', style: G.text(13, color: G.faint))),
            if (data.focus.isNotEmpty) _line('Focus', data.focus, color: G.accent),
            if (data.keepGoing.isNotEmpty) _line('Keep going', data.keepGoing),
            if (data.parked.isNotEmpty) _line('Parked', data.parked, color: G.faint),
            const SizedBox(height: 10),
            if (s.over)
              Text('Tap to review it and pick what comes next.', style: G.text(14, w: FontWeight.w600, color: G.accent))
            else ...[
              Text(_hint, style: G.text(13, color: G.faint)),
              // The event half of "event or date, whichever comes first": the person says it happened.
              GestureDetector(
                onTap: onReview,
                child: Padding(padding: const EdgeInsets.only(top: 8), child: Text('Done early? Review this season', style: G.text(14, color: G.accent))),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The sleep fix in My life: this week's times, and once a week "how many days
/// did you wake on time?" which moves the plan on at 5 of 7 (decisions log #13).
class _SleepCard extends StatelessWidget {
  final SleepPlan? plan;
  final VoidCallback onOpen;
  final Future<void> Function(int days) onCheckin;
  const _SleepCard({required this.plan, required this.onOpen, required this.onCheckin});

  @override
  Widget build(BuildContext context) {
    final p = plan;
    if (p == null) {
      return Material(
        color: G.card,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Fix my sleep', style: G.text(18, w: FontWeight.w600, height: 1.2)),
                  const SizedBox(height: 2),
                  Text('A fixed wake time first. One jump, then a little each week.', style: G.text(14, color: G.muted, height: 1.3)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: G.faint),
            ]),
          ),
        ),
      );
    }
    final s = p.current;
    // Asked once the week is up; until then the card just shows the times.
    final due = !p.done && p.stepAt != null && DateTime.now().difference(p.stepAt!).inDays >= 6;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Sleep', style: G.text(18, w: FontWeight.w600, height: 1.2))),
          Text(p.done ? 'on target' : 'week ${p.step} of ${p.steps.length}', style: G.text(14, color: G.muted)),
        ]),
        const SizedBox(height: 4),
        Text('Sleep ${clockLabel(s.sleep)} · wake ${clockLabel(s.wake)}', style: G.text(16, color: G.accent, height: 1.3)),
        if (due) ...[
          const SizedBox(height: 12),
          Text('How many days did you wake by ${clockLabel(s.wake)} this week?', style: G.text(15, height: 1.3)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var d = 0; d <= 7; d++)
              SizedBox(
                width: 40,
                height: 40,
                child: TextButton(
                  onPressed: () => onCheckin(d),
                  style: TextButton.styleFrom(backgroundColor: G.surfaceHigh, foregroundColor: G.ink, padding: EdgeInsets.zero, shape: const CircleBorder()),
                  child: Text('$d', style: G.text(15, w: FontWeight.w600)),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

/// One plan Ally runs (fitness for now): start it, or see where it stands.
class _PlanRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PlanRow({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: G.card,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: G.text(18, w: FontWeight.w600, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: G.text(14, color: G.muted, height: 1.3)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: G.faint),
            ]),
          ),
        ),
      );
}
