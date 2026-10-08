import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../areas/areas_screen.dart';
import '../guide/guide_style.dart';
import '../habits/habit_detail_screen.dart';
import '../habits/habits_screen.dart';
import '../shell/life_cubit.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/tasks_screen.dart';
import 'now_cubit.dart';

const _blockName = {
  'MORNING': 'Morning',
  'COMMUTE': 'Commute',
  'OFFICE': 'Office',
  'GYM': 'Gym',
  'EVENING': 'Evening',
  'NIGHT': 'Night',
  'ANYTIME': 'Anytime',
};

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

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
            children: [
              Text('Today', style: G.display(36)),
              if (plan != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(DateFormat('EEEE d MMMM').format(DateTime.parse('${plan['date']}')), style: G.text(13, color: G.muted))),
              const SizedBox(height: 10),
              if (_error != null) Text(_error!, style: G.text(15, color: G.muted)),
              if (plan == null && _error == null) Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: G.muted, strokeWidth: 1.5))),
              if ((_stale?['total'] ?? 0) as num > 0) _stale_(),
              if (plan != null) ..._today(plan),
              if (plan != null) ..._folded(plan),
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
      margin: const EdgeInsets.only(bottom: 18, top: 6),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: G.ink, width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Still want ${total > items.length ? 'these' : (items.length == 1 ? 'this' : 'these ${items.length}')}?', style: G.voice(24, color: G.ink)),
        const SizedBox(height: 6),
        Text('Untouched for a month. Letting go is allowed.', style: G.text(13, color: G.muted)),
        const SizedBox(height: 8),
        for (final i in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.line))),
            child: Text('${i['title']}', style: G.text(16, w: FontWeight.w500)),
          ),
        const SizedBox(height: 4),
        Row(children: [
          TextButton(
              style: TextButton.styleFrom(padding: const EdgeInsets.only(right: 20)),
              onPressed: () => _resolveStale(letGo: false),
              child: Text('Keep them', style: G.text(15, w: FontWeight.w700))),
          TextButton(onPressed: () => _resolveStale(letGo: true), child: Text('Let them go', style: G.text(15, w: FontWeight.w500, color: G.muted))),
        ]),
      ]),
    );
  }

  List<Widget> _today(Map<String, dynamic> plan) {
    final blocks = ((plan['today']['blocks'] as List?) ?? const []).whereType<Json>().toList();
    if (blocks.isEmpty) {
      return [Text('Nothing planned for today. Ask me what to do now, or tell me what is on your mind.', style: G.voice(20, color: G.ink))];
    }
    final nowPart = DayStrip.partOf(DateTime.now());
    final clock = DateFormat('h:mm').format(DateTime.now());
    var nowDrawn = false;
    return [
      for (final b in blocks) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Row(children: [
            Container(width: 8, height: 8, color: G.part('${b['block']}')),
            const SizedBox(width: 8),
            Text(_blockName['${b['block']}'] ?? '${b['block']}', style: G.text(13, w: FontWeight.w700, color: '${b['block']}' == nowPart ? G.ink : G.muted)),
          ]),
        ),
        for (final item in (b['items'] as List).whereType<Json>()) ...[
          if (!nowDrawn && '${b['block']}' == nowPart && item['done'] != true && (nowDrawn = true))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Text('$clock now', style: G.text(11, w: FontWeight.w700, color: G.accent)),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: G.accent)),
              ]),
            ),
          _row(item),
        ],
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
    ].join(', ');
    return InkWell(
      onTap: () => _open(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!done) HapticFeedback.lightImpact();
              _tick(item);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 1, bottom: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? G.good : Colors.transparent,
                  border: done ? null : Border.all(color: G.muted, width: 1.5),
                ),
                child: done ? Icon(Icons.check_rounded, size: 14, color: G.dark ? G.bg : Colors.white) : null,
              ),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['title']}', style: G.text(16, w: FontWeight.w500, color: done ? G.muted : G.ink).copyWith(decoration: done ? TextDecoration.lineThrough : null)),
              if (meta.isNotEmpty) Text(meta, style: G.text(13, color: G.muted)),
            ]),
          ),
        ]),
      ),
    );
  }

  // Everything else, folded: the week, goals, habits, and what is waiting for later.
  List<Widget> _folded(Map<String, dynamic> plan) {
    final week = plan['thisWeek'] as Json;
    final days = ((week['days'] as List?) ?? const []).whereType<Json>().toList();
    final carried = ((week['carried'] as List?) ?? const []).whereType<Json>().toList();
    final projects = plan['projects'] as Json;
    final office = ((projects['office'] as List?) ?? const []).whereType<Json>().toList();
    final personal = ((projects['personal'] as List?) ?? const []).whereType<Json>().toList();
    final habits = ((plan['habits'] as List?) ?? const []).whereType<Json>().toList();
    final later = ((plan['later'] as Json)['count'] as num).toInt();

    Widget section(String title, List<Widget> children, {bool empty = false, String count = ''}) => Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 10),
            title: Row(children: [
              Expanded(child: Text(title, style: G.text(16, w: FontWeight.w700))),
              Text(count, style: G.text(14, color: G.muted)),
            ]),
            trailing: const SizedBox.shrink(),
            iconColor: G.muted,
            children: empty ? [Align(alignment: Alignment.centerLeft, child: Text('Nothing here.', style: G.text(15, color: G.muted)))] : children,
          ),
        );

    return [
      const SizedBox(height: 18),
      Container(height: 2, color: G.ink),
      section('This week', [
        if (carried.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 2), child: Text('Carried over, no rush', style: G.text(13, w: FontWeight.w700, color: G.carried))),
          for (final i in carried) _row(i),
        ],
        for (final d in days) ...[
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: Text(DateFormat('EEEE d MMM').format(DateTime.parse('${d['date']}')), style: G.text(14, w: FontWeight.w700, color: G.muted))),
          for (final i in (d['items'] as List).whereType<Json>()) _row(i),
        ],
      ], empty: days.isEmpty && carried.isEmpty, count: '${days.fold<int>(0, (n, d) => n + ((d['items'] as List).length)) + carried.length} things'),
      section('Goals', [
        if (office.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Office', style: G.text(14, w: FontWeight.w700, color: G.muted))),
        for (final p in office) _goal(p),
        if (personal.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text('Personal', style: G.text(14, w: FontWeight.w700, color: G.muted))),
        for (final p in personal) _goal(p),
      ], empty: office.isEmpty && personal.isEmpty, count: '${office.length + personal.length}'),
      section('Habits', [
        for (final h in habits)
          InkWell(
            onTap: () => _open({'type': 'HABIT', 'id': h['id']}),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(child: Text('${h['title']}', style: G.text(16, w: FontWeight.w600))),
                Text(h['stage'] == 'AUTOMATIC' ? 'automatic' : '${h['consistency']} of 28 days', style: G.text(13, color: G.muted)),
              ]),
            ),
          ),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _openAll(() => HabitsScreen(onOpenMore: () {}), 'Habits'), child: Text('Open habits', style: G.text(14, w: FontWeight.w700)))),
      ], empty: habits.isEmpty, count: '${habits.length}'),
      section('Later', count: '$later waiting', [
        Text('$later to-do${later == 1 ? '' : 's'} with no date or further out. They wait; nothing is lost.', style: G.text(15, color: G.muted)),
        Row(children: [
          TextButton(onPressed: () => _openAll(() => TasksScreen(onOpenMore: () {}), 'All to-dos'), child: Text('See all to-dos', style: G.text(14, w: FontWeight.w700))),
          TextButton(onPressed: () => _openAll(() => AreasScreen(onOpenMore: () {}), 'Areas'), child: Text('Areas', style: G.text(14, w: FontWeight.w700))),
        ]),
      ]),
    ];
  }

  Widget _goal(Json p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p['title']}${p['status'] == 'PAUSED' ? ' (paused)' : ''}', style: G.text(16, w: FontWeight.w700)),
          Text('${p['message']}', style: G.text(14, color: G.muted)),
        ]),
      );
}
