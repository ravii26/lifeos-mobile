import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// How a focus session ended. Leaving any other way (back, close) is [stopped]:
/// it logs nothing and costs nothing.
///
/// [later]: not today; the caller moves it to tomorrow. [letGo]: the step was
/// let go from here (already saved; [FocusOutcome.undoId] undoes it).
enum FocusEnd { done, stopped, stuck, later, letGo }

class FocusOutcome {
  final FocusEnd end;

  /// Whole minutes actually spent, never less than 1 when done.
  final int minutes;

  /// Done, but only the small first move: it counts, and the step stays.
  final bool smaller;

  /// For [FocusEnd.letGo]: what undoes it.
  final String? undoId;
  const FocusOutcome(this.end, this.minutes, {this.smaller = false, this.undoId});
}

/// What the "doing it" screen says about a step (GET /steps/:id/brief).
class StepBrief {
  /// What it is part of: a goal, or the area.
  final String? goal;
  final String? why;

  /// A first move of about two minutes.
  final String begin;

  /// What done looks like.
  final String done;
  const StepBrief({this.goal, this.why, required this.begin, required this.done});

  factory StepBrief.fromJson(Json j) {
    final from = j['from'] is Json ? j['from'] as Json : const <String, dynamic>{};
    return StepBrief(goal: asStringOrNull(from['goal']), why: asStringOrNull(from['why']), begin: asString(j['begin']), done: asString(j['done']));
  }
}

/// 0:07, 12:45, 1:02:10. Counts up: the time given, not the time left.
String elapsedText(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// The screen after Start. For a step it is a "doing it" screen: what the step
/// is part of, how to begin (a first two-minute move), what done looks like,
/// and Done / Smaller / Later; the timer runs quietly and can be shown. For
/// anything else it is one thing, a ring that fills towards the planned
/// length, and a clock that counts up. It reads the wall clock, so it stays
/// right while the phone is in a pocket. Going past the planned time is fine;
/// the ring just stays full.
///
/// Pops with a [FocusOutcome]; null (back button) means stopped.
class FocusSessionScreen extends StatefulWidget {
  final String title;

  /// The planned length. The ring is full at this point.
  final int minutes;
  final String? firstStep;
  final String? areaName;
  final Color? areaColor;

  /// With both, this is a step: its brief is loaded and the screen says how to
  /// begin and what done looks like. Without them (or on a server from before
  /// briefs) it is the timer screen.
  final String? stepId;
  final LifeRepository? repo;

  /// For tests.
  final DateTime Function()? clock;

  const FocusSessionScreen({
    super.key,
    required this.title,
    required this.minutes,
    this.firstStep,
    this.areaName,
    this.areaColor,
    this.stepId,
    this.repo,
    this.clock,
  });

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> with SingleTickerProviderStateMixin {
  DateTime get _now => (widget.clock ?? DateTime.now)();

  late DateTime? _since = _now; // null while paused
  Duration _banked = Duration.zero; // time before the last pause
  Timer? _tick;
  bool _reachedPlan = false;

  // The step's brief: loading until it arrives; null after = the timer screen.
  late bool _briefing = widget.stepId != null && widget.repo != null;
  StepBrief? _brief;
  // The name shown, which a rewrite can change.
  late String _title = widget.title;
  // Doing only the first move: it counts, and the step stays.
  bool _small = false;
  bool _showTimer = false;
  bool _busy = false;

  // A slow breath on the ring while the clock runs.
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  Duration get _elapsed => _banked + (_since == null ? Duration.zero : _now.difference(_since!));
  bool get _running => _since != null;
  Duration get _plan => Duration(minutes: widget.minutes < 1 ? 1 : widget.minutes);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    if (_briefing) _loadBrief();
  }

  Future<void> _loadBrief() async {
    StepBrief? b;
    try {
      b = StepBrief.fromJson(await widget.repo!.stepBrief(widget.stepId!));
      if (b.begin.isEmpty || b.done.isEmpty) b = null;
    } catch (_) {
      // No connection, or a server from before briefs: the timer screen still works.
      b = null;
    }
    if (mounted) {
      setState(() {
        _brief = b;
        _briefing = false;
      });
    }
  }

  /// "Not clear what to do?": a clearer wording (Ally's, or their own), or let it go.
  Future<void> _notClear() async {
    final repo = widget.repo!, id = widget.stepId!;
    String? suggestion;
    setState(() => _busy = true);
    try {
      suggestion = await repo.clearerStep(id);
    } on ApiException {
      // They can still write it their own way.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    var typed = suggestion ?? _title;
    final answer = await showAllySheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Make it clear', style: AllyType.h2(color: ctx.ac.ink)),
        const SizedBox(height: Sp.x1),
        Text(
          suggestion == null ? 'Say it the way you would actually do it.' : "Ally's wording is below. Change it until it is something you could start now.",
          style: AllyType.body(color: ctx.ac.muted),
        ),
        const SizedBox(height: Sp.x3),
        TextFormField(
          initialValue: typed,
          maxLength: 200,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: AllyType.body(color: ctx.ac.ink),
          decoration: const InputDecoration(hintText: 'What exactly to do', counterText: ''),
          onChanged: (v) => typed = v,
        ),
        const SizedBox(height: Sp.x3),
        AllyButton('Use this', wide: true, onPressed: () => Navigator.of(ctx).pop('save')),
        AllyButton('Let this step go', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(ctx).pop('letgo')),
      ]),
    );
    if (answer == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (answer == 'letgo') {
        final r = await repo.letGoStep(id);
        if (mounted) Navigator.of(context).pop(FocusOutcome(FocusEnd.letGo, 0, undoId: r.activityId));
        return;
      }
      final name = typed.trim();
      if (name.isEmpty || name == _title) return;
      final was = _title;
      final r = await repo.editStep(id, title: name);
      if (!mounted) return;
      setState(() {
        _title = name;
        _briefing = true;
      });
      final undoId = r.activityId;
      showAllyToast(context, 'Step reworded.',
          onUndo: undoId == null
              ? null
              : () async {
                  try {
                    await repo.undo(undoId);
                    if (mounted) setState(() => _title = was);
                  } on ApiException catch (e) {
                    if (mounted) showAllyToast(context, e.message);
                  }
                });
      await _loadBrief();
    } on ApiException catch (e) {
      if (mounted) showAllyToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreath();
  }

  void _syncBreath() {
    if (_running && !Motion.reduced(context)) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    setState(() {
      if (!_reachedPlan && _elapsed >= _plan) {
        _reachedPlan = true;
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _togglePause() {
    setState(() {
      if (_running) {
        _banked = _elapsed;
        _since = null;
      } else {
        _since = _now;
      }
    });
    _syncBreath();
  }

  int get _spentMinutes {
    final m = (_elapsed.inSeconds / 60).round();
    return m < 1 ? 1 : m;
  }

  void _end(FocusEnd end) => Navigator.of(context).pop(FocusOutcome(end, end == FocusEnd.done ? _spentMinutes : 0, smaller: end == FocusEnd.done && _small));

  Widget _card(AllyColors c, String label, String text) => AllyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text(text, style: AllyType.body(color: c.ink)),
        ]),
      );

  /// The "doing it" screen for a step: what it is part of, how to begin, what
  /// done looks like. The clock still counts quietly, so Done knows the time given.
  Widget _doing(BuildContext context, AllyColors c, StepBrief? b, double progress, Color ringColor) {
    final part = b?.goal ?? widget.areaName;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        [if (widget.areaName != null) widget.areaName!, _small ? '2 min' : '${widget.minutes} min'].join(' · ').toUpperCase(),
        style: AllyType.eyebrow(color: c.faint),
      ),
      const SizedBox(height: Sp.x2),
      Text(_small && b != null ? b.begin : _title, style: AllyType.h1(color: c.ink)),
      if (_small) ...[
        const SizedBox(height: Sp.x1),
        Text('The small version of: $_title', style: AllyType.small(color: c.muted)),
      ] else if (part != null && b?.goal != null) ...[
        const SizedBox(height: Sp.x1),
        Text('Part of: $part', style: AllyType.small(color: c.muted)),
        if (b?.why != null && b!.why!.isNotEmpty) Text('Why: ${b.why}', style: AllyType.small(color: c.faint)),
      ],
      const SizedBox(height: Sp.x4),
      if (b == null)
        const AllySkeleton(height: 140, radius: Rad.card)
      else ...[
        if (!_small) ...[
          _card(c, 'HOW TO BEGIN', b.begin),
          const SizedBox(height: Sp.x3),
        ],
        _card(c, 'DONE LOOKS LIKE', _small ? 'Just that. Two minutes on it counts.' : b.done),
      ],
      const SizedBox(height: Sp.x4),
      if (_showTimer)
        Center(
          child: ProgressRing(
            value: progress,
            color: ringColor,
            size: 132,
            stroke: 10,
            semanticLabel: 'Time given',
            child: Text(elapsedText(_elapsed), style: AllyType.num(color: c.ink, size: 26)),
          ),
        ),
      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (!_showTimer) Text('${elapsedText(_elapsed)} so far', style: AllyType.num(color: c.faint)),
        AllyButton(_showTimer ? 'Hide timer' : 'Show timer', kind: AllyButtonKind.ghost, onPressed: () => setState(() => _showTimer = !_showTimer)),
        if (_showTimer) AllyButton(_running ? 'Pause' : 'Resume', kind: AllyButtonKind.ghost, onPressed: _togglePause),
      ]),
      const SizedBox(height: Sp.x3),
      AllyButton('Done', icon: Icons.check_rounded, wide: true, onPressed: _busy ? null : () => _end(FocusEnd.done)),
      const SizedBox(height: Sp.x2),
      Row(children: [
        if (!_small && b != null) ...[
          Expanded(
            child: AllyButton('Smaller', kind: AllyButtonKind.secondary, wide: true, onPressed: _busy ? null : () => setState(() => _small = true)),
          ),
          const SizedBox(width: Sp.x2),
        ],
        Expanded(child: AllyButton('Later', kind: AllyButtonKind.secondary, wide: true, onPressed: _busy ? null : () => _end(FocusEnd.later))),
      ]),
      const SizedBox(height: Sp.x2),
      AllyButton(_busy ? 'One moment…' : 'Not clear what to do?', kind: AllyButtonKind.ghost, wide: true, onPressed: _busy ? null : _notClear),
      Text('Closing this logs nothing and costs nothing.', textAlign: TextAlign.center, style: AllyType.small(color: c.faint)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final c = context.ac;
    final ringColor = widget.areaColor ?? c.ink;
    final progress = (_elapsed.inMilliseconds / _plan.inMilliseconds).clamp(0.0, 1.0).toDouble();
    final status = !_running
        ? 'Paused'
        : _reachedPlan
            ? "That's the time you planned. Keep going, or call it done."
            : "You've started. That's the hard part.";
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Stop without logging',
            icon: Icon(Icons.close_rounded, color: c.muted),
            onPressed: () => _end(FocusEnd.stopped),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x5),
            child: _briefing || _brief != null
                ? _doing(context, c, _brief, progress, ringColor)
                : ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - Sp.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [
                    Text(
                      [if (widget.areaName != null) widget.areaName!, '${widget.minutes} min'].join(' · ').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AllyType.eyebrow(color: c.faint),
                    ),
                    const SizedBox(height: Sp.x2),
                    Text(_title, textAlign: TextAlign.center, style: AllyType.h1(color: c.ink)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.x5),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _breath,
                        builder: (context, child) =>
                            Transform.scale(scale: 1 + 0.035 * Curves.easeInOut.transform(_breath.value), child: child),
                        child: LayoutBuilder(builder: (context, b) {
                          final size = b.maxWidth.clamp(160.0, 240.0).toDouble();
                          return ProgressRing(
                            value: progress,
                            color: ringColor,
                            size: size,
                            stroke: 12,
                            semanticLabel: 'Time given',
                            child: FractionallySizedBox(
                              widthFactor: 0.7,
                              child: FittedBox(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(elapsedText(_elapsed), style: AllyType.num(color: c.ink, size: 44)),
                                  Text(_running ? 'of ${widget.minutes} min' : 'paused', style: AllyType.small(color: c.muted)),
                                ]),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(status, textAlign: TextAlign.center, style: AllyType.body(color: c.muted)),
                    ),
                    if (widget.firstStep != null && widget.firstStep!.isNotEmpty) ...[
                      const SizedBox(height: Sp.x1),
                      Text('First: ${widget.firstStep}', textAlign: TextAlign.center, style: AllyType.small(color: c.faint)),
                    ],
                    const SizedBox(height: Sp.x4),
                    AllyButton('Done', icon: Icons.check_rounded, wide: true, onPressed: () => _end(FocusEnd.done)),
                    const SizedBox(height: Sp.x2),
                    Row(children: [
                      Expanded(
                        child: AllyButton(_running ? 'Pause' : 'Resume',
                            kind: AllyButtonKind.secondary, wide: true, onPressed: _togglePause),
                      ),
                      const SizedBox(width: Sp.x2),
                      Expanded(
                        child: AllyButton("I'm stuck",
                            kind: AllyButtonKind.secondary, wide: true, onPressed: () => _end(FocusEnd.stuck)),
                      ),
                    ]),
                    const SizedBox(height: Sp.x3),
                    Text('Stopping early logs nothing and costs nothing.',
                        textAlign: TextAlign.center, style: AllyType.small(color: c.faint)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
