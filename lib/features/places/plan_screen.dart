import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';
import '../habits/habit_detail_screen.dart';
import '../habits/habits_screen.dart';
import '../shell/life_cubit.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/tasks_screen.dart';
import 'now_cubit.dart';

/// "3 things. About an hour." Nothing left says so plainly.
String planSummary(int open, int minutes) {
  if (open == 0) return 'Nothing left for today.';
  final things = open == 1 ? '1 thing' : '$open things';
  if (minutes <= 0) return '$things.';
  if (minutes < 45) return '$things. About $minutes minutes.';
  final hours = (minutes / 30).round() / 2;
  final shown = hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toString();
  return '$things. About ${hours == 1 ? 'an hour' : '$shown hours'}.';
}

/// Plan: today first, in order. The week and later wait behind a tab, so the
/// screen never opens as one long list of everything.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _repo = getIt<LifeRepository>();
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _stale;
  String? _error;
  int _tab = 0; // Today, Week, Later

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.plan(), _repo.staleTodos()]);
      if (!mounted) return;
      setState(() {
        _plan = results[0];
        _stale = results[1];
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && _plan == null) setState(() => _error = e.message);
    }
  }

  void _say(String text, {String? undoId}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: undoId == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    await _repo.undo(undoId);
                    placesRefresh.value++;
                  } on ApiException catch (e) {
                    _say(e.message);
                  }
                }),
      ));
  }

  Future<void> _answer(Json item, Future<String?> Function() send) async {
    if (item['done'] == true) return;
    HapticFeedback.lightImpact();
    // Show it ticked straight away; the server catches up (or queues it offline).
    setState(() => item['done'] = true);
    try {
      final id = await send();
      placesRefresh.value++;
      _say('Done', undoId: id);
    } on QueuedOfflineException {
      _say("Saved offline. It'll sync when you're back online.");
    } on ApiException catch (e) {
      setState(() => item['done'] = false);
      _say(e.message);
    }
  }

  Future<void> _tick(Json item) =>
      _answer(item, () => _repo.respondNow(item['type'] == 'HABIT' ? 'HABIT' : 'TASK', '${item['id']}', 'DONE'));

  // A suggestion done from Plan: logged the same way as from Now.
  Future<void> _doSuggested(Json item) => _answer(
        item,
        () => _repo.respondNow('${item['sourceType']}', '${item['sourceId']}', 'DONE',
            minutes: asInt(item['minutes']), count: item['count'] == null ? null : asInt(item['count'])),
      );

  void _open(Json item) {
    final life = context.read<LifeCubit>();
    final id = '${item['id']}';
    final page = item['type'] == 'HABIT' ? HabitDetailScreen(habitId: id) : TaskDetailScreen(taskId: id);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BlocProvider.value(value: life, child: page)));
  }

  // [title] adds a top bar, for a page that does not bring its own.
  void _openAll(Widget Function() page, [String? title]) {
    final life = context.read<LifeCubit>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: life,
        child: title == null
            ? page()
            : Scaffold(
                backgroundColor: G.bg,
                appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0, title: Text(title, style: G.text(20, w: FontWeight.w500, height: 1.2))),
                body: page(),
              ),
      ),
    ));
  }

  Future<void> _resolveStale({required bool letGo}) async {
    final items = ((_stale?['items'] as List?) ?? const []).whereType<Json>().map((i) => '${i['id']}').toList();
    if (items.isEmpty) return;
    try {
      final id = await _repo.resolveStale(keepIds: letGo ? const [] : items, letGoIds: letGo ? items : const []);
      placesRefresh.value++;
      _say(letGo ? 'Let go. One less thing to carry.' : "Kept. I'll ask again in a month.", undoId: letGo ? id : null);
    } on ApiException catch (e) {
      _say(e.message);
    }
  }

  /// Nothing at all to plan yet: one sentence and one button instead of empty sections.
  static bool _isEmpty(Map<String, dynamic> plan) {
    List<Json> list(Object? v) => ((v as List?) ?? const []).whereType<Json>().toList();
    final today = list(plan['today']?['blocks']).expand((b) => list(b['items']));
    final week = list(plan['thisWeek']?['days']).expand((d) => list(d['items']));
    final projects = plan['projects'] as Json? ?? const {};
    return today.isEmpty &&
        week.isEmpty &&
        list(plan['thisWeek']?['carried']).isEmpty &&
        list(plan['habits']).isEmpty &&
        list(plan['suggested']).isEmpty &&
        list(projects['office']).isEmpty &&
        list(projects['personal']).isEmpty &&
        ((plan['later'] as Json?)?['count'] as num? ?? 0) == 0;
  }

  static const _blockNames = {'MORNING': 'Morning', 'COMMUTE': 'Commute', 'OFFICE': 'Day', 'GYM': 'Gym', 'EVENING': 'Evening', 'NIGHT': 'Night'};

  // The same map objects every build, so a tick shows before the server answers.
  List<Json> _todayItems(Map<String, dynamic> plan) => [
        for (final b in ((plan['today']?['blocks'] as List?) ?? const []).whereType<Json>())
          for (final i in ((b['items'] as List?) ?? const []).whereType<Json>()) i..['_block'] = b['block'],
      ];

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final empty = plan != null && _isEmpty(plan);
    final open = plan == null ? const <Json>[] : _todayItems(plan).where((i) => i['done'] != true).toList();
    final minutes = open.fold<int>(0, (s, i) => s + (i['minutes'] == null ? 0 : asInt(i['minutes'])));
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
            children: [
              Text(const ['Today', 'This week', 'Later'][_tab], style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
              if (plan != null && !empty && _tab == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(planSummary(open.length, minutes), style: G.text(19, color: G.muted, height: 1.3)),
                ),
              const SizedBox(height: 16),
              if (empty) const _EmptyPlan(),
              if (!empty) _Tabs(selected: _tab, onTap: (i) => setState(() => _tab = i)),
              if (!empty) const SizedBox(height: 18),
              if (_error != null) Text(_error!, style: G.text(17, color: G.muted, height: 1.4)),
              if (plan == null && _error == null)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 1.5))),
              if ((_stale?['total'] ?? 0) as num > 0) _staleCard(),
              if (plan != null && !empty && _tab == 0) ..._today(plan),
              if (plan != null && !empty && _tab == 1) ..._week(plan),
              if (plan != null && !empty && _tab == 2) ..._later(plan),
              if (!empty) ...[
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: GPill('All to-dos', onTap: () => _openAll(() => TasksScreen(onOpenMore: () {})))),
                  const SizedBox(width: 8),
                  Expanded(child: GPill('Habits', onTap: () => _openAll(() => HabitsScreen(onOpenMore: () {}), 'Habits'))),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _staleCard() {
    final items = ((_stale?['items'] as List?) ?? const []).whereType<Json>().toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(items.length == 1 ? 'Still want this?' : 'Still want these?', style: G.text(21, w: FontWeight.w500, height: 1.2)),
        const SizedBox(height: 4),
        Text('Untouched for a month. Letting go is allowed.', style: G.text(16, color: G.muted, height: 1.3)),
        const SizedBox(height: 8),
        for (final i in items)
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('${i['title']}', style: G.text(17, height: 1.3))),
        Row(children: [
          TextButton(
            onPressed: () => _resolveStale(letGo: false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 46), foregroundColor: G.accent),
            child: Text('Keep them', style: G.text(16, w: FontWeight.w600, color: G.accent, height: 1.2)),
          ),
          TextButton(
            onPressed: () => _resolveStale(letGo: true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 46), foregroundColor: G.muted),
            child: Text('Let them go', style: G.text(16, color: G.muted, height: 1.2)),
          ),
        ]),
      ]),
    );
  }

  String _timeOf(Json item) {
    final at = item['at'] != null ? DateTime.tryParse('${item['at']}')?.toLocal() : null;
    if (at != null) return DateFormat('h a').format(at).toLowerCase();
    return _blockNames['${item['_block']}'] ?? '';
  }

  List<Widget> _today(Map<String, dynamic> plan) {
    final items = _todayItems(plan);
    final next = items.where((i) => i['done'] != true).firstOrNull;
    final carried = ((plan['thisWeek']?['carried'] as List?) ?? const []).whereType<Json>().toList();
    final habits = ((plan['habits'] as List?) ?? const []).whereType<Json>().toList();
    final ideas = ((plan['suggested'] as List?) ?? const []).whereType<Json>().toList();
    return [
      for (final i in items)
        if (identical(i, next)) _nextCard(i) else _timelineRow(i),
      if (ideas.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('Ideas for the rest of today', style: G.text(16, color: G.muted, height: 1.2)),
        const SizedBox(height: 4),
        for (final b in ideas)
          for (final i in ((b['items'] as List?) ?? const []).whereType<Json>()) _ideaRow(i),
      ],
      if (carried.isNotEmpty) ...[
        const SizedBox(height: 14),
        GFoldSection(
          header: Text('From earlier days (${carried.length})', style: G.text(17, height: 1.2)),
          content: Column(children: [for (final i in carried) _row(i)]),
        ),
      ],
      if (habits.isNotEmpty) ...[
        const SizedBox(height: 10),
        GFoldSection(
          header: Text('Habits (${habits.length})', style: G.text(17, height: 1.2)),
          content: Column(children: [
            for (final h in habits)
              InkWell(
                onTap: () => _open({'type': 'HABIT', 'id': h['id']}),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(children: [
                    Expanded(child: Text('${h['title']}', style: G.text(17, height: 1.25))),
                    Text(h['stage'] == 'AUTOMATIC' ? 'part of your day' : '${h['consistency']} of 28 days', style: G.text(15, color: G.muted, height: 1.2)),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    ];
  }

  Widget _nextCard(Json i) {
    final ink = G.onInk;
    final minimum = '${i['minimum'] ?? ''}';
    final time = _timeOf(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: G.accent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(time.isEmpty ? 'Next up' : 'Next up · $time', style: G.text(15, w: FontWeight.w500, color: ink, height: 1.2))),
                if (i['minutes'] != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text('${i['minutes']} min', style: G.text(15, color: ink, height: 1.2))),
              ]),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${i['title']}', style: G.text(24, w: FontWeight.w600, color: ink, height: 1.15, letterSpacing: -0.4)),
              ),
              if (minimum.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Text('Smallest version: $minimum', style: G.text(16, color: ink, height: 1.3))),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _tick(i),
                  style: TextButton.styleFrom(foregroundColor: ink, minimumSize: const Size(64, 44)),
                  icon: Icon(Icons.check_rounded, size: 20, color: ink),
                  label: Text('Done', style: G.text(17, w: FontWeight.w600, color: ink, height: 1.2)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tickBox(bool done, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: done ? G.accent : Colors.transparent, border: done ? null : Border.all(color: G.faint, width: 2)),
              child: done ? Icon(Icons.check_rounded, size: 17, color: G.onInk) : null,
            ),
          ),
        ),
      );

  Widget _timelineRow(Json i) {
    final done = i['done'] == true;
    return InkWell(
      onTap: () => _open(i),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          _tickBox(done, () => _tick(i)),
          Expanded(
            child: Text('${i['title']}',
                style: G.text(19, color: done ? G.faint : G.ink, height: 1.25).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: G.faint)),
          ),
          const SizedBox(width: 10),
          Text(_timeOf(i), style: G.text(15, color: G.muted, height: 1.2)),
        ]),
      ),
    );
  }

  Widget _ideaRow(Json i) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _tickBox(i['done'] == true, () => _doSuggested(i)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i['title']}', style: G.text(18, height: 1.25)),
              Text('${i['why']}', style: G.text(15, color: G.muted, height: 1.3)),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 12, left: 8), child: Text('${i['minutes']} min', style: G.text(15, color: G.muted, height: 1.2))),
      ]);

  List<Widget> _week(Map<String, dynamic> plan) {
    final week = plan['thisWeek'] as Json;
    final days = ((week['days'] as List?) ?? const []).whereType<Json>().toList();
    final carried = ((week['carried'] as List?) ?? const []).whereType<Json>().toList();
    return [
      if (carried.isNotEmpty) ...[
        Text('From earlier days', style: G.text(16, color: G.accent, height: 1.2)),
        for (final i in carried) _row(i),
        const SizedBox(height: 14),
      ],
      if (carried.isEmpty && days.every((d) => ((d['items'] as List?) ?? const []).isEmpty))
        Text('Nothing planned for this week yet.', style: G.text(19, color: G.muted, height: 1.3)),
      for (final d in days.where((d) => ((d['items'] as List?) ?? const []).isNotEmpty)) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text(DateFormat('EEEE d MMM').format(DateTime.parse('${d['date']}')), style: G.text(16, color: G.muted, height: 1.2)),
        ),
        for (final i in (d['items'] as List).whereType<Json>()) _row(i),
      ],
    ];
  }

  List<Widget> _later(Map<String, dynamic> plan) {
    final projects = plan['projects'] as Json;
    final office = ((projects['office'] as List?) ?? const []).whereType<Json>().toList();
    final personal = ((projects['personal'] as List?) ?? const []).whereType<Json>().toList();
    final later = ((plan['later'] as Json)['count'] as num).toInt();
    return [
      if (later > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text('$later to-do${later == 1 ? '' : 's'} with no date. They wait; nothing is lost.', style: G.text(19, color: G.muted, height: 1.3)),
        ),
      if (later == 0 && office.isEmpty && personal.isEmpty) Text('Nothing saved for later.', style: G.text(19, color: G.muted, height: 1.3)),
      if (office.isNotEmpty) ...[
        Text('Work goals', style: G.text(16, color: G.muted, height: 1.2)),
        const SizedBox(height: 6),
        for (final p in office) _goal(p),
        const SizedBox(height: 14),
      ],
      if (personal.isNotEmpty) ...[
        Text('Personal goals', style: G.text(16, color: G.muted, height: 1.2)),
        const SizedBox(height: 6),
        for (final p in personal) _goal(p),
      ],
    ];
  }

  Widget _row(Json item) {
    final done = item['done'] == true;
    final at = item['at'] != null ? DateTime.tryParse('${item['at']}')?.toLocal() : null;
    final meta = [
      if (at != null) DateFormat('h:mm a').format(at),
      if (item['minutes'] != null) '${item['minutes']} min',
      if (item['type'] == 'HABIT') 'habit',
      if (item['projectTitle'] != null) '${item['projectTitle']}',
    ].join(' · ');
    return InkWell(
      onTap: () => _open(item),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _tickBox(done, () => _tick(item)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['title']}',
                  style: G.text(18, color: done ? G.faint : G.ink, height: 1.25).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: G.faint)),
              if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta, style: G.text(15, color: G.muted, height: 1.25))),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _goal(Json p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p['title']}${p['status'] == 'PAUSED' ? ' (paused)' : ''}', style: G.text(19, w: FontWeight.w500, height: 1.25)),
          const SizedBox(height: 2),
          Text('${p['message']}', style: G.text(15, color: G.muted, height: 1.3)),
        ]),
      );
}

class _Tabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _Tabs({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(26)),
        child: Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: selected == i ? G.accent : Colors.transparent, borderRadius: BorderRadius.circular(22)),
                  child: Text(const ['Today', 'Week', 'Later'][i],
                      style: G.text(16, w: selected == i ? FontWeight.w600 : FontWeight.w400, color: selected == i ? G.onInk : G.ink, height: 1.2)),
                ),
              ),
            ),
        ]),
      );
}

/// Plan with nothing in it yet: what this place is for, and one way to fill it.
class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Nothing planned yet.', style: G.text(26, w: FontWeight.w500, height: 1.2)),
          const SizedBox(height: 8),
          Text('Your day, your week and your goals show up here once you tell Ally about them.', style: G.text(18, color: G.muted, height: 1.4)),
          const SizedBox(height: 22),
          GPill('Plan a goal', primary: true, onTap: () => starterRequest.value = Starter.goal),
        ]),
      );
}
