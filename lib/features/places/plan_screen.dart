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

/// Plan: today by part of the day first. The week, goals and habits wait
/// below, folded away, so the screen never opens as one long list of everything.
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

  Future<void> _tick(Json item) async {
    if (item['done'] == true) return;
    final isHabit = item['type'] == 'HABIT';
    // Show it ticked straight away; the server catches up (or queues it offline).
    setState(() => item['done'] = true);
    try {
      final id = await _repo.respondNow(isHabit ? 'HABIT' : 'TASK', '${item['id']}', 'DONE');
      placesRefresh.value++;
      _say('Done', undoId: id);
    } on QueuedOfflineException {
      _say("Saved offline. It'll sync when you're back online.");
    } on ApiException catch (e) {
      setState(() => item['done'] = false);
      _say(e.message);
    }
  }

  // A suggestion done from Plan: logged the same way as from Now.
  Future<void> _doSuggested(Json item) async {
    if (item['done'] == true) return;
    setState(() => item['done'] = true);
    try {
      final id = await _repo.respondNow('${item['sourceType']}', '${item['sourceId']}', 'DONE',
          minutes: asInt(item['minutes']), count: item['count'] == null ? null : asInt(item['count']));
      placesRefresh.value++;
      _say('Done', undoId: id);
    } on QueuedOfflineException {
      _say("Saved offline. It'll sync when you're back online.");
    } on ApiException catch (e) {
      setState(() => item['done'] = false);
      _say(e.message);
    }
  }

  static const _blockNames = {'MORNING': 'Morning', 'COMMUTE': 'Commute', 'GYM': 'Gym', 'EVENING': 'Evening', 'NIGHT': 'Night'};

  // What the brain would place in each free part of the rest of today, with why.
  List<Widget> _suggested(Map<String, dynamic> plan) {
    final blocks = ((plan['suggested'] as List?) ?? const []).whereType<Json>().toList();
    if (blocks.isEmpty) return const [];
    return [
      Text('Ideas for the rest of today', style: G.text(15, w: FontWeight.w600)),
      const SizedBox(height: 2),
      Text("From your goals, deadlines and free time. Tick one when it's done.", style: G.label(size: 11, color: G.faint)),
      const SizedBox(height: 8),
      for (final b in blocks) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text('${_blockNames['${b['block']}'] ?? '${b['block']}'} · ${b['start']}–${b['end']}',
              style: G.label(size: 11, color: G.part('${b['block']}'), w: FontWeight.w600)),
        ),
        for (final i in ((b['items'] as List?) ?? const []).whereType<Json>())
          InkWell(
            onTap: () => _doSuggested(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(i['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: i['done'] == true ? G.good : G.faint),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i['title']}', style: G.text(14.5, w: FontWeight.w500)),
                    Text('${i['why']}', style: G.text(12.5, color: G.muted, height: 1.35)),
                  ]),
                ),
                Text('${i['minutes']} min', style: G.label(size: 11, color: G.faint)),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 10),
      Container(height: 0.5, color: G.lineSoft),
      const SizedBox(height: 10),
    ];
  }

  void _open(Json item) {
    final life = context.read<LifeCubit>();
    final id = '${item['id']}';
    final page = item['type'] == 'HABIT' ? HabitDetailScreen(habitId: id) : TaskDetailScreen(taskId: id);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BlocProvider.value(value: life, child: page)));
  }

  void _openAll(Widget Function() page, String title) {
    final life = context.read<LifeCubit>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: life,
        child: Scaffold(
          backgroundColor: G.bg,
          appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0, title: Text(title, style: G.text(17, w: FontWeight.w700))),
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

  int _selectedTab = 0; // 0: Today, 1: Week, 2: Later

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

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final empty = plan != null && _isEmpty(plan);
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now).toLowerCase();

    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              // Nocturne Top Bar
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(Icons.bedtime_outlined, size: 20, color: G.accent),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Plan', style: G.voice(17, color: G.ink)),
                    Text('Today and what is ahead', style: G.label(size: 11, color: G.faint)),
                  ]),
                ]),
              ]),
              const SizedBox(height: 12),

              if (empty) const _EmptyPlan(),
              // Segmented Range Pill [Today | Week | Later]
              if (!empty) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: G.inset,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(children: [
                    for (var i = 0; i < 3; i++)
                      GestureDetector(
                        onTap: () => setState(() => _selectedTab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _selectedTab == i ? G.surfaceHigh : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            ['Today', 'Week', 'Later'][i],
                            style: G.label(
                              size: 11,
                              color: _selectedTab == i ? G.ink : G.muted,
                              w: _selectedTab == i ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
                Text(timeStr, style: G.label(size: 11, color: G.faint)),
              ]),
              const SizedBox(height: 10),

              // Day Flow Timeline Bar: Morning, Day, Evening, Night
              if (!empty) ...[DayStrip(now: now), const SizedBox(height: 14)],

              if (_error != null) Text(_error!, style: G.text(14, color: G.muted)),
              if (plan == null && _error == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),

              if ((_stale?['total'] ?? 0) as num > 0) _stale_(),

              if (plan != null && !empty && _selectedTab == 0) ..._suggested(plan),
              if (plan != null && !empty && _selectedTab == 0) ..._todayFolded(plan),
              if (plan != null && !empty && _selectedTab == 1) ..._weekFolded(plan),
              if (plan != null && !empty && _selectedTab == 2) ..._laterFolded(plan),

              // See everything
              if (!empty) ...[
              const SizedBox(height: 18),
              Container(height: 0.5, color: G.lineSoft),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('See all', style: G.label(size: 11, color: G.faint)),
                Row(children: [
                  _QuickPill(
                    label: 'Habits',
                    onTap: () => _openAll(() => HabitsScreen(onOpenMore: () {}), 'Habits'),
                  ),
                  const SizedBox(width: 6),
                  _QuickPill(
                    label: 'To-dos',
                    onTap: () => _openAll(() => TasksScreen(onOpenMore: () {}), 'All to-dos'),
                  ),
                  const SizedBox(width: 6),
                  _QuickPill(
                    label: '+ Add',
                    accent: true,
                    onTap: () => _openAll(() => TasksScreen(onOpenMore: () {}), 'New item'),
                  ),
                ]),
              ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stale_() {
    final items = ((_stale?['items'] as List?) ?? const []).whereType<Json>().toList();
    final total = (_stale!['total'] as num).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: G.inset,
        border: Border.all(color: G.lineSoft, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.archive_outlined, size: 16, color: G.faint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Still want ${total > items.length ? 'these' : (items.length == 1 ? 'this' : 'these $items.length')}?',
              style: G.voice(15, color: G.ink),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Untouched for a month. Letting go is allowed.', style: G.label(size: 11, color: G.faint)),
        const SizedBox(height: 8),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('• ${i['title']}', style: G.text(13, color: G.muted)),
          ),
        const SizedBox(height: 8),
        Row(children: [
          TextButton(
            onPressed: () => _resolveStale(letGo: false),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            child: Text('Keep them', style: G.label(size: 11, color: G.accent, w: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => _resolveStale(letGo: true),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            child: Text('Let them go', style: G.label(size: 11, color: G.faint)),
          ),
        ]),
      ]),
    );
  }

  List<Widget> _todayFolded(Map<String, dynamic> plan) {
    final blocks = ((plan['today']['blocks'] as List?) ?? const []).whereType<Json>().toList();
    final allItems = <Json>[];
    for (final b in blocks) {
      allItems.addAll((b['items'] as List).whereType<Json>());
    }

    final activeItem = allItems.where((i) => i['done'] != true).firstOrNull;
    final settledItems = allItems.where((i) => i['done'] == true).toList();
    final carriedItems = ((plan['thisWeek']?['carried'] as List?) ?? const []).whereType<Json>().toList();
    final habits = ((plan['habits'] as List?) ?? const []).whereType<Json>().toList();

    return [
      // SECTION 1: Active Focus Node (Primary Unfolded Anchor)
      if (activeItem != null)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: G.card,
            border: Border.all(color: G.lineSoft, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: G.accent),
                ),
                const SizedBox(width: 6),
                Text('Next up', style: G.label(size: 10, color: G.accent, w: FontWeight.w600)),
              ]),
              if (activeItem['minutes'] != null)
                Text('${activeItem['minutes']} min', style: G.label(size: 11, color: G.faint)),
            ]),
            const SizedBox(height: 8),
            Text(
              '${activeItem['title']}',
              style: G.text(17, w: FontWeight.w500, color: G.ink, height: 1.3),
            ),
            // The smallest version, when the item has one (real data, nothing invented).
            if ('${activeItem['minimum'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  color: G.inset,
                  border: Border(left: BorderSide(color: G.accent, width: 2)),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                ),
                child: Text('Smallest version: ${activeItem['minimum']}', style: G.voice(13, color: G.muted)),
              ),
            ],
            const SizedBox(height: 12),
            Container(height: 0.5, color: G.lineSoft),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _tick(activeItem);
                },
                style: TextButton.styleFrom(
                  backgroundColor: G.goodSoft,
                  foregroundColor: G.good,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: Icon(Icons.check_rounded, size: 16, color: G.good),
                label: Text('Done', style: G.label(size: 11, color: G.good, w: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => _open(activeItem),
                child: Text('Open', style: G.label(size: 11, color: G.muted)),
              ),
            ]),
          ]),
        )
      // Nothing scheduled: say so only when there are no ideas above either.
      else if (((plan['suggested'] as List?) ?? const []).isEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: G.card,
            border: Border.all(color: G.lineSoft, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Nothing left for today.',
            style: G.voice(15, color: G.muted),
          ),
        ),

      // Only sections that have something in them.
      if (settledItems.isNotEmpty) GFoldSection(
        initiallyExpanded: false,
        header: Row(children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: G.good),
          const SizedBox(width: 8),
          Text('Done today', style: G.text(14, w: FontWeight.w500)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: G.goodSoft,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text('${settledItems.length}',
                style: G.label(size: 10, color: G.good, w: FontWeight.w600)),
          ),
        ]),
        content: Column(
          children: [
            if (settledItems.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('No settled items yet today.', style: G.label(size: 12, color: G.faint)),
              ),
            for (final i in settledItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(
                      '${i['title']}',
                      style: G.text(13, color: G.faint).copyWith(decoration: TextDecoration.lineThrough),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),

      if (carriedItems.isNotEmpty) GFoldSection(
        initiallyExpanded: false,
        header: Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: G.carried),
          ),
          const SizedBox(width: 8),
          Text('From earlier days', style: G.text(14, w: FontWeight.w500)),
          const SizedBox(width: 8),
          Text('${carriedItems.length}', style: G.label(size: 11, color: G.carried)),
        ]),
        content: Column(
          children: [
            if (carriedItems.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Nothing carried over. A clean slate.', style: G.label(size: 12, color: G.faint)),
              ),
            for (final i in carriedItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text('${i['title']}', style: G.text(13, color: G.muted))),
                ]),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),

      if (habits.isNotEmpty) GFoldSection(
        initiallyExpanded: false,
        header: Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: G.accent),
          const SizedBox(width: 8),
          Text('Habits', style: G.text(14, w: FontWeight.w500)),
          const Spacer(),
          Text('${habits.length} habits', style: G.label(size: 11, color: G.faint)),
          const SizedBox(width: 6),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: G.good),
          ),
        ]),
        content: Column(
          children: [
            for (final h in habits)
              InkWell(
                onTap: () => _open({'type': 'HABIT', 'id': h['id']}),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text('${h['title']}', style: G.text(13, w: FontWeight.w500))),
                    Text(
                      h['stage'] == 'AUTOMATIC' ? 'part of your day now' : 'done ${h['consistency']} of the last 28 days',
                      style: G.label(size: 11, color: G.faint),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _weekFolded(Map<String, dynamic> plan) {
    final week = plan['thisWeek'] as Json;
    final days = ((week['days'] as List?) ?? const []).whereType<Json>().toList();
    final carried = ((week['carried'] as List?) ?? const []).whereType<Json>().toList();

    return [
      if (carried.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text('From earlier days', style: G.label(size: 11, color: G.carried, w: FontWeight.w600)),
        ),
        for (final i in carried) _row(i),
        const SizedBox(height: 12),
      ],
      if (carried.isEmpty && days.every((d) => ((d['items'] as List?) ?? const []).isEmpty))
        Text('Nothing planned for this week yet.', style: G.voice(15, color: G.muted)),
      for (final d in days.where((d) => ((d['items'] as List?) ?? const []).isNotEmpty)) ...[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            DateFormat('EEEE d MMM').format(DateTime.parse('${d['date']}')),
            style: G.label(size: 11, color: G.faint, w: FontWeight.w600),
          ),
        ),
        for (final i in (d['items'] as List).whereType<Json>()) _row(i),
      ],
    ];
  }

  List<Widget> _laterFolded(Map<String, dynamic> plan) {
    final projects = plan['projects'] as Json;
    final office = ((projects['office'] as List?) ?? const []).whereType<Json>().toList();
    final personal = ((projects['personal'] as List?) ?? const []).whereType<Json>().toList();
    final later = ((plan['later'] as Json)['count'] as num).toInt();

    return [
      if (later > 0) ...[
        Text('$later to-do${later == 1 ? '' : 's'} with no date. They wait; nothing is lost.',
            style: G.voice(15, color: G.muted)),
        const SizedBox(height: 14),
      ],
      if (later == 0 && office.isEmpty && personal.isEmpty)
        Text('Nothing saved for later.', style: G.voice(15, color: G.muted)),
      if (office.isNotEmpty) ...[
        Text('Work goals', style: G.label(size: 11, color: G.faint, w: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final p in office) _goal(p),
        const SizedBox(height: 14),
      ],
      if (personal.isNotEmpty) ...[
        Text('Personal goals', style: G.label(size: 11, color: G.faint, w: FontWeight.w600)),
        const SizedBox(height: 4),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.lineSoft, width: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!done) HapticFeedback.lightImpact();
              _tick(item);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: done ? G.good : Colors.transparent,
                  border: done ? null : Border.all(color: G.line, width: 1),
                ),
                child: done ? Icon(Icons.check_rounded, size: 13, color: G.bg) : null,
              ),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${item['title']}',
                style: G.text(14, w: FontWeight.w500, color: done ? G.faint : G.ink)
                    .copyWith(decoration: done ? TextDecoration.lineThrough : null),
              ),
              if (meta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(meta, style: G.label(size: 11, color: G.faint)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _goal(Json p) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: G.inset,
          border: Border.all(color: G.lineSoft, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p['title']}${p['status'] == 'PAUSED' ? ' (paused)' : ''}',
              style: G.text(14, w: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${p['message']}', style: G.label(size: 11, color: G.faint)),
        ]),
      );
}

class _QuickPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool accent;
  const _QuickPill({required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: accent ? G.accent.withValues(alpha: 0.15) : G.inset,
            border: Border.all(color: accent ? G.accent.withValues(alpha: 0.4) : G.lineSoft, width: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: G.label(
              size: 11,
              color: accent ? G.accent : G.muted,
              w: accent ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
}

/// Plan with nothing in it yet: what this place is for, and one way to fill it.
class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nothing planned yet.', style: G.voice(20, color: G.ink)),
          const SizedBox(height: 6),
          Text('Your day, your week and your goals show up here once you tell Ally about them.',
              style: G.text(14, color: G.muted, height: 1.45)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => starterRequest.value = Starter.goal,
            style: FilledButton.styleFrom(
              backgroundColor: G.accent,
              foregroundColor: G.bg,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text('Plan a goal', style: G.text(15, w: FontWeight.w600, color: G.bg)),
          ),
        ]),
      );
}
