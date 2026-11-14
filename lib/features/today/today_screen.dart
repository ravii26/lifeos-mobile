import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../chat/starters.dart' show talkRequest;
import '../places/done_screen.dart' show DoneChoice;
import '../places/now_cubit.dart';
import '../areas/areas_overview.dart';
import '../session/completion_screen.dart';
import '../session/focus_session_screen.dart';
import 'day_shape.dart';
import 'today_sheets.dart';

/// Today: the day as a dial, the free time in it, one thing to do, and the
/// rest of today's list. Opening the app should answer "what now?" at a glance.
///
/// The one thing comes from [NowCubit] (the rules engine on the server); the
/// dial and the list are built on the phone from the day's shape and plan.
class TodayScreen extends StatefulWidget {
  final String firstName;

  /// Opens the screen this one replaces, while its extras are being rebuilt.
  final VoidCallback? onOpenPrevious;

  /// For tests.
  final LifeRepository? repo;
  final DateTime Function()? clock;

  const TodayScreen({super.key, required this.firstName, this.onOpenPrevious, this.repo, this.clock});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final LifeRepository _repo = widget.repo ?? getIt<LifeRepository>();
  List<DayBlockInfo> _blocks = const [];
  List<TodayItem> _items = const [];
  bool _loaded = false;
  String? _loadError;
  Timer? _minute;

  DateTime get _now => (widget.clock ?? DateTime.now)();
  int get _nowMin => _now.hour * 60 + _now.minute;

  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
    // Keeps the hand on the dial and the free minutes honest.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    _minute?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.daySchedule(), _repo.plan()]);
      if (!mounted) return;
      final schedule = results[0] as List<Map<String, dynamic>>;
      setState(() {
        // The server counts weekdays from Sunday = 0.
        _blocks = blocksForWeekday(schedule, _now.weekday % 7);
        _items = todayItems(results[1] as Map<String, dynamic>);
        _loaded = true;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = _loaded ? null : e.message);
    }
  }

  // ---- actions ----

  static String _shown(NowOption o) => o.smaller && o.minimum.isNotEmpty ? o.minimum.replaceAll(RegExp(r'\.$'), '') : o.title;

  /// Opens the focus session. Null when it was closed with the back button.
  Future<FocusOutcome?> _focus(NowOption o, {int? minutes}) => Navigator.of(context).push<FocusOutcome>(MaterialPageRoute(
        builder: (_) => FocusSessionScreen(
          title: _shown(o),
          minutes: minutes ?? (o.minutes > 0 ? o.minutes : 25),
          firstStep: !o.smaller && o.minimum.isNotEmpty ? o.minimum.replaceAll(RegExp(r'\.$'), '') : null,
          areaName: o.areaName,
        ),
      ));

  /// Where the option's area stands this week, when the server says which
  /// area it is. Best effort: the completion moment works without it.
  Future<({AreaStanding area, int index})?> _areaOf(NowOption o) async {
    final id = o.areaId;
    if (id == null) return null;
    try {
      final all = (await loadAreasOverview(_repo)).areas;
      final i = all.indexWhere((a) => a.id == id);
      return i < 0 ? null : (area: all[i], index: i);
    } on ApiException {
      return null;
    }
  }

  /// "You're free until 23:00." or "Next free time: 18:30." or nothing.
  String? _nextFreeLine() {
    final w = freeWindow(_blocks, _nowMin);
    if (w == null) return null;
    return w.now ? "You're free until ${clock(w.end)}." : 'Next free time: ${clock(w.start)}.';
  }

  Future<DoneChoice?> _celebrate(BuildContext themed, NowOption o,
      {int? minutes, ({AreaStanding area, int index})? before, required bool canUndo}) async {
    // Read before the await: the colour comes from the theme.
    final colors = themed.ac;
    AreaMove? move;
    if (before != null) {
      final after = await _areaOf(o);
      move = AreaMove(
        name: before.area.name,
        color: colors.area(before.index),
        from: before.area.value,
        to: after?.area.value ?? before.area.value,
        status: after?.area.status,
      );
    }
    if (!mounted) return null;
    return Navigator.of(context).push<DoneChoice>(MaterialPageRoute(
      builder: (_) => CompletionScreen(title: _shown(o), minutes: minutes, area: move, nextLine: _nextFreeLine(), canUndo: canUndo),
    ));
  }

  /// Start on the Today card.
  Future<void> _start(BuildContext themed, NowOption o, {int? minutes}) async {
    final cubit = context.read<NowCubit>();
    final before = _areaOf(o); // fetched while the session runs
    final outcome = await _focus(o, minutes: minutes);
    if (!mounted) return;
    switch (outcome?.end) {
      case FocusEnd.done:
        final was = await before;
        if (!mounted || !themed.mounted) return;
        await _done(themed, o, minutes: outcome!.minutes, before: was);
      case FocusEnd.stuck:
        await cubit.smaller();
      case FocusEnd.stopped || null:
        break;
    }
  }

  /// Done, from the card (no timer) or at the end of a session.
  Future<void> _done(BuildContext themed, NowOption o, {int? minutes, ({AreaStanding area, int index})? before}) async {
    final cubit = context.read<NowCubit>();
    final was = before ?? await _areaOf(o);
    if (!await cubit.done(minutes: minutes) || !mounted || !themed.mounted) return;
    final choice = await _celebrate(themed, o, minutes: minutes, before: was, canUndo: cubit.state.undoId != null);
    if (choice == DoneChoice.undo) await cubit.undo();
    if (choice == DoneChoice.finishedForToday) await cubit.finishForToday();
  }

  Future<void> _notNow(BuildContext themed, NowState s, NowOption o) async {
    final cubit = context.read<NowCubit>();
    final picked = await showAllySheet<NotNowAnswer>(
      themed,
      builder: (_) => NotNowSheet(
        title: _shown(o),
        isGoal: o.sourceType == 'PROJECT',
        // For a habit the server would make "weekend" permanent, which is not what this asks.
        canWeekend: o.sourceType != 'HABIT',
        canLetGo: !s.lowEnergy,
        canShrink: !o.smaller,
      ),
    );
    if (picked == null || !mounted || !themed.mounted) return;
    switch (picked.choice) {
      case 'CLEAR':
        final go = await showAllySheet<bool>(
          themed,
          builder: (_) => StepsSheet(title: o.title, firstStep: o.minimum, detail: o.detail),
        );
        if (go == true && mounted && themed.mounted) await _start(themed, o);
      case 'SMALLER':
        await cubit.smaller();
      case 'FIVE':
        await _start(themed, o, minutes: 5);
      case 'SKIP':
        await cubit.notNow(reason: picked.reason);
      default:
        await cubit.moveCurrent(picked.choice, reason: picked.reason);
    }
  }

  /// "I've got time": pick a length, get what fits, start it.
  Future<void> _gotTime(BuildContext themed, FreeWindow? free) async {
    final cubit = context.read<NowCubit>();
    final o = await showAllySheet<NowOption>(
      themed,
      builder: (_) => FreeTimeSheet(repo: _repo, items: _items, suggestedMinutes: free != null && free.now ? free.minutes : null),
    );
    if (o == null || !mounted || !themed.mounted) return;
    await _runFree(themed, o);
    unawaited(cubit.load());
  }

  /// A pick from "I've got time": not the Today card, so it is answered directly.
  Future<void> _runFree(BuildContext themed, NowOption o, {int? minutes}) async {
    final before = _areaOf(o);
    final outcome = await _focus(o, minutes: minutes);
    if (!mounted || !themed.mounted) return;
    if (outcome?.end == FocusEnd.stuck) {
      // Stuck: the first step written out, then five minutes of it.
      final go = await showAllySheet<bool>(themed, builder: (_) => StepsSheet(title: o.title, firstStep: o.minimum, detail: o.detail));
      if (go == true && mounted && themed.mounted) await _runFree(themed, o, minutes: 5);
      return;
    }
    if (outcome?.end != FocusEnd.done) return;
    final was = await before;
    String? undoId;
    try {
      undoId = await _repo.respondNow(o.sourceType, o.sourceId, 'DONE', minutes: outcome!.minutes, count: o.count);
      placesRefresh.value++;
    } on QueuedOfflineException {
      if (themed.mounted) _toast(themed, "Saved offline. It'll sync when you're back online.");
      return;
    } on ApiException catch (e) {
      if (themed.mounted) _toast(themed, e.message);
      return;
    }
    if (!themed.mounted) return;
    final choice = await _celebrate(themed, o, minutes: outcome.minutes, before: was, canUndo: undoId != null);
    if (choice == DoneChoice.undo && undoId != null) {
      try {
        await _repo.undo(undoId);
        placesRefresh.value++;
      } on ApiException catch (e) {
        if (themed.mounted) _toast(themed, e.message);
      }
    }
    if (choice == DoneChoice.finishedForToday && mounted) await context.read<NowCubit>().finishForToday();
  }

  Future<void> _tick(BuildContext themed, TodayItem item) async {
    if (item.done) return;
    final cubit = context.read<NowCubit>();
    // Ticked at once; the server catches up, or it queues offline.
    setState(() => item.done = true);
    try {
      final id = await _repo.respondNow(item.sourceType, item.id, 'DONE');
      placesRefresh.value++;
      if (themed.mounted) _toast(themed, 'Done', undoId: id);
      unawaited(cubit.load());
    } on QueuedOfflineException {
      if (themed.mounted) _toast(themed, "Saved offline. It'll sync when you're back online.");
    } on ApiException catch (e) {
      if (mounted) setState(() => item.done = false);
      if (themed.mounted) _toast(themed, e.message);
    }
  }

  void _toast(BuildContext themed, String text, {String? undoId}) {
    showAllyToast(
      themed,
      text,
      onUndo: undoId == null
          ? null
          : () async {
              final cubit = context.read<NowCubit>();
              try {
                await _repo.undo(undoId);
                placesRefresh.value++;
                unawaited(cubit.load());
              } on ApiException catch (e) {
                if (themed.mounted) showAllyToast(themed, e.message);
              }
            },
    );
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AllyTheme.dark(),
      child: Builder(
        builder: (themed) => BlocConsumer<NowCubit, NowState>(
          listenWhen: (p, c) => (c.error != null && c.error != p.error) || (c.note != null && c.note != p.note),
          listener: (_, s) {
            if (s.error != null) {
              showAllyToast(themed, s.error!);
            } else if (s.note != null) {
              final cubit = context.read<NowCubit>();
              showAllyToast(themed, s.note!, onUndo: s.undoId == null ? null : cubit.undo);
            }
          },
          builder: (_, s) => _page(themed, s),
        ),
      ),
    );
  }

  Widget _page(BuildContext themed, NowState s) {
    final c = themed.ac;
    final cubit = context.read<NowCubit>();
    final now = _now;
    final free = freeWindow(_blocks, _nowMin);
    final open = _items.where((i) => !i.done).length;

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.ink,
          backgroundColor: c.raised,
          onRefresh: () async {
            await Future.wait([cubit.load(), _load()]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x4, Sp.side, Sp.x6),
            children: [
              Stagger(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}', style: AllyType.eyebrow(color: c.faint)),
                  const SizedBox(height: Sp.x1),
                  Text(widget.firstName.isEmpty ? greeting(now.hour) : '${greeting(now.hour)}, ${widget.firstName}',
                      style: AllyType.h1(color: c.ink)),
                ]),
                if (s.fromSaved) const AllyBanner("You're offline. This is the copy saved on this phone."),
                if (s.restart != null) _restart(c, cubit, s),
                if (_blocks.isNotEmpty) _dial(c, free),
                _suggestion(themed, c, cubit, s, free),
                if (s.advice != null) _advice(c, cubit, s),
                AllyButton("I've got time",
                    kind: AllyButtonKind.secondary,
                    icon: Icons.hourglass_empty_rounded,
                    wide: true,
                    onPressed: () => _gotTime(themed, free)),
                _list(themed, c, open),
                if (s.prep.isNotEmpty) _prep(c, s),
                if (!s.sick && !s.restedToday)
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Low energy today', style: AllyType.body(color: c.ink)),
                        Text('Smaller versions until tomorrow.', style: AllyType.small(color: c.faint)),
                      ]),
                    ),
                    AllySwitch(
                      value: s.lowEnergy,
                      semanticLabel: 'Low energy today',
                      onChanged: (v) => v ? cubit.lowEnergy() : cubit.endLowEnergy(),
                    ),
                  ]),
                if (widget.onOpenPrevious != null)
                  Center(
                    child: AllyButton('Open the previous Now screen',
                        kind: AllyButtonKind.ghost, onPressed: widget.onOpenPrevious),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dial(AllyColors c, FreeWindow? free) {
    final Widget centre;
    final String label;
    if (free == null) {
      label = 'Your day. No more free time today.';
      centre = Column(mainAxisSize: MainAxisSize.min, children: [
        Text('TODAY', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: 4),
        Text(clock(_nowMin), style: AllyType.big(color: c.ink)),
        const SizedBox(height: 2),
        Text('day is winding down', style: AllyType.small(color: c.muted)),
      ]);
    } else {
      label = free.now
          ? 'Your day. Free now for ${duration(free.minutes)}, until ${clock(free.end)}.'
          : 'Your day. Free at ${clock(free.start)} for ${duration(free.minutes)}.';
      centre = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(free.now ? 'FREE NOW' : 'FREE AT ${clock(free.start)}', style: AllyType.eyebrow(color: c.freeInk)),
        const SizedBox(height: 4),
        Text(duration(free.minutes), style: AllyType.big(color: c.ink)),
        const SizedBox(height: 2),
        Text('until ${clock(free.end)}', style: AllyType.small(color: c.muted)),
      ]);
    }
    return DayDial(
      now: _nowMin,
      parts: dialParts(_blocks, _items, planned: c.muted),
      semanticLabel: label,
      child: centre,
    );
  }

  Widget _suggestion(BuildContext themed, AllyColors c, NowCubit cubit, NowState s, FreeWindow? free) {
    if (s.status == NowStatus.loading && s.options.isEmpty) {
      return const AllySkeleton(height: 190, radius: Rad.card);
    }
    if (s.status == NowStatus.error && s.options.isEmpty) {
      return AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Couldn't load right now", style: AllyType.h2(color: c.ink)),
          const SizedBox(height: Sp.x1),
          Text(s.error ?? _loadError ?? 'Check your connection and try again.', style: AllyType.body(color: c.muted)),
          const SizedBox(height: Sp.x4),
          AllyButton('Try again', onPressed: () {
            cubit.load();
            _load();
          }),
        ]),
      );
    }
    if (s.sick) {
      return _plain(c, 'Rest today', s.message.isEmpty ? 'Nothing is asked of you while you are unwell.' : s.message,
          'I am feeling better', cubit.feelingBetter);
    }
    if (s.restedToday) {
      return _plain(c, 'Done for today', 'Nothing more will be suggested until tomorrow.', 'Show me more', cubit.resumeToday);
    }
    final o = s.current;
    if (o == null) {
      return _plain(
        c,
        s.kind == 'REST' ? 'Nothing right now' : 'Nothing on your list yet',
        s.message.isEmpty ? 'Tell Ally what you want to get done and it will plan the first step.' : s.message,
        'Tell Ally',
        () => talkRequest.value++,
      );
    }
    // Marigold only when this really is free time.
    final inFree = free != null && free.now;
    return AllyCard(
      key: ValueKey('${o.sourceId}${o.smaller}'),
      free: inFree,
      strong: !inFree,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(o.smaller ? 'SMALLER VERSION' : (s.focus ? 'DUE SOON' : 'RIGHT NOW'),
                style: AllyType.eyebrow(color: inFree ? c.freeInk : c.faint)),
          ),
          if (o.minutes > 0) Text(duration(o.minutes), style: AllyType.num(color: c.muted)),
        ]),
        const SizedBox(height: Sp.x2),
        Text(_shown(o), style: AllyType.h2(color: c.ink)),
        if (o.why.isNotEmpty) ...[
          const SizedBox(height: Sp.x1),
          Text(o.why, style: AllyType.body(color: c.muted)),
        ],
        if (s.message.isNotEmpty && s.focus) ...[
          const SizedBox(height: Sp.x1),
          Text(s.message, style: AllyType.small(color: c.faint)),
        ],
        const SizedBox(height: Sp.x4),
        AllyButton('Start',
            kind: inFree ? AllyButtonKind.free : AllyButtonKind.main,
            icon: Icons.play_arrow_rounded,
            wide: true,
            onPressed: s.busy ? null : () => _start(themed, o)),
        const SizedBox(height: Sp.x2),
        Row(children: [
          Expanded(
            child: AllyButton('Done', kind: AllyButtonKind.secondary, wide: true, onPressed: s.busy ? null : () => _done(themed, o)),
          ),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: AllyButton('Not now',
                kind: AllyButtonKind.ghost, wide: true, onPressed: s.busy ? null : () => _notNow(themed, s, o)),
          ),
        ]),
      ]),
    );
  }

  Widget _plain(AllyColors c, String title, String text, String action, VoidCallback onAction) => AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AllyType.h2(color: c.ink)),
          const SizedBox(height: Sp.x1),
          Text(text, style: AllyType.body(color: c.muted)),
          const SizedBox(height: Sp.x4),
          AllyButton(action, kind: AllyButtonKind.secondary, onPressed: onAction),
        ]),
      );

  Widget _restart(AllyColors c, NowCubit cubit, NowState s) {
    final r = s.restart!;
    final switchTo = r.canLightWeek ? r.suggestBlock : null;
    return AllyCard(
      strong: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Welcome back', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text(r.insight ?? 'No catching up needed. Start from today.', style: AllyType.body(color: c.muted)),
        if (r.record != null) ...[
          const SizedBox(height: Sp.x1),
          Text(r.record!, style: AllyType.small(color: c.faint)),
        ],
        const SizedBox(height: Sp.x4),
        if (switchTo != null)
          AllyButton(switchTo == 'MORNING' ? 'Move to mornings, light week' : 'Move to evenings, light week',
              wide: true, onPressed: s.busy ? null : () => cubit.restartPlan(lightWeek: true, switchTo: switchTo))
        else if (r.canLightWeek)
          AllyButton('Start with a light week', wide: true, onPressed: s.busy ? null : () => cubit.restartPlan(lightWeek: true)),
        const SizedBox(height: Sp.x1),
        AllyButton('Keep as is', kind: AllyButtonKind.ghost, wide: true, onPressed: cubit.dismissRestart),
      ]),
    );
  }

  Widget _advice(AllyColors c, NowCubit cubit, NowState s) {
    final a = s.advice!;
    return AllyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.message, style: AllyType.body(color: c.ink)),
        if (a.actions.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final (label, choice) in a.actions)
              AllyButton(label, kind: AllyButtonKind.secondary, onPressed: s.busy ? null : () => cubit.adviceChoice(choice)),
          ]),
        ],
      ]),
    );
  }

  Widget _list(BuildContext themed, AllyColors c, int open) {
    if (!_loaded) {
      return _loadError == null
          ? const AllySkeleton(height: 120, radius: Rad.card)
          : Text(_loadError!, style: AllyType.small(color: c.faint));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('TODAY', style: AllyType.eyebrow(color: c.faint))),
        if (_items.isNotEmpty) Text('$open left', style: AllyType.num(color: c.faint, size: 12)),
      ]),
      const SizedBox(height: Sp.x3),
      if (_items.isEmpty)
        Text('Nothing else is planned for today.', style: AllyType.body(color: c.muted))
      else
        AllyCard(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x1, Sp.x1, Sp.x1),
          child: Column(children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) Divider(color: c.line, height: 1),
              _row(themed, c, _items[i]),
            ],
          ]),
        ),
    ]);
  }

  Widget _row(BuildContext themed, AllyColors c, TodayItem item) => Row(children: [
        SizedBox(
          width: 74,
          child: Text(item.at != null ? clock(item.at!) : partName(item.block),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: item.at != null ? AllyType.num(color: c.faint) : AllyType.small(color: c.faint)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x2),
            child: Text(
              item.title,
              style: AllyType.body(color: item.done ? c.faint : c.ink, w: FontWeight.w500)
                  .copyWith(decoration: item.done ? TextDecoration.lineThrough : null),
            ),
          ),
        ),
        AllyCheck(done: item.done, semanticLabel: item.title, onTap: item.done ? null : () => _tick(themed, item)),
      ]);

  Widget _prep(AllyColors c, NowState s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('GET READY FOR TOMORROW', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        for (final p in s.prep) Text('· $p', style: AllyType.body(color: c.muted)),
      ]);
}
