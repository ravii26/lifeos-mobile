import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// How a focus session ended. Leaving any other way (back, close) is [stopped]:
/// it logs nothing and costs nothing.
enum FocusEnd { done, stopped, stuck }

class FocusOutcome {
  final FocusEnd end;

  /// Whole minutes actually spent, never less than 1 when done.
  final int minutes;
  const FocusOutcome(this.end, this.minutes);
}

/// 0:07, 12:45, 1:02:10. Counts up: the time given, not the time left.
String elapsedText(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// The screen after Start: one thing, a ring that fills towards the planned
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

  /// For tests.
  final DateTime Function()? clock;

  const FocusSessionScreen({
    super.key,
    required this.title,
    required this.minutes,
    this.firstStep,
    this.areaName,
    this.areaColor,
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

  // A slow breath on the ring while the clock runs.
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  Duration get _elapsed => _banked + (_since == null ? Duration.zero : _now.difference(_since!));
  bool get _running => _since != null;
  Duration get _plan => Duration(minutes: widget.minutes < 1 ? 1 : widget.minutes);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _update());
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

  void _end(FocusEnd end) => Navigator.of(context).pop(FocusOutcome(end, end == FocusEnd.done ? _spentMinutes : 0));

  @override
  Widget build(BuildContext context) => Theme(data: AllyTheme.dark(), child: Builder(builder: _page));

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
            child: ConstrainedBox(
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
                    Text(widget.title, textAlign: TextAlign.center, style: AllyType.h1(color: c.ink)),
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
