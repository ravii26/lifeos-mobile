import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/done_screen.dart' show DoneChoice;
import '../today/day_shape.dart' show duration;

/// Where the finished thing's area stood before and after, when it is known.
class AreaMove {
  final String name;
  final Color color;

  /// This week's progress, 0 to 1.
  final double from;
  final double to;
  final String? status;
  const AreaMove({required this.name, required this.color, required this.from, required this.to, this.status});
}

/// The moment after Done: a tick draws, the area's ring moves forward, and
/// nothing is rushed. Pops with a [DoneChoice], or null for "back to today".
class CompletionScreen extends StatefulWidget {
  final String title;

  /// Minutes actually given; null when it was ticked without a timer.
  final int? minutes;
  final AreaMove? area;

  /// "You're free until 23:00." or "Next free time: 18:30."
  final String? nextLine;
  final bool canUndo;

  const CompletionScreen({super.key, required this.title, this.minutes, this.area, this.nextLine, required this.canUndo});

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> with SingleTickerProviderStateMixin {
  // The ring moves first, the tick draws over its end (the prototype's 350 ms delay).
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    HapticFeedback.lightImpact();
    Motion.reduced(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _headline {
    final a = widget.area, m = widget.minutes;
    if (m != null && a != null) return '${duration(m)} into ${a.name}';
    if (m != null) return '${duration(m)} given';
    return 'Done';
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyTheme.dark(), child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final c = context.ac;
    final a = widget.area;
    final ring = CurvedAnimation(parent: _c, curve: const Interval(0.28, 1, curve: Motion.ease));
    final tick = CurvedAnimation(parent: _c, curve: const Interval(0.2, 0.6, curve: Motion.ease));
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x5, Sp.side, Sp.x5),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - Sp.x5 * 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: Sp.x5),
                    Column(children: [
                      Semantics(
                        label: a == null
                            ? 'Done'
                            : 'Done. ${a.name} moved from ${(a.from * 100).round()} to ${(a.to * 100).round()} percent of this week',
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) => CustomPaint(
                            size: const Size.square(150),
                            painter: _DonePainter(
                              track: c.raised,
                              ring: a?.color ?? c.done,
                              tick: c.ink,
                              from: a?.from ?? 0,
                              to: a?.to ?? 1,
                              ringT: ring.value,
                              tickT: tick.value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Sp.x5),
                      Text('DONE', style: AllyType.eyebrow(color: c.faint)),
                      const SizedBox(height: Sp.x1),
                      Text(_headline, textAlign: TextAlign.center, style: AllyType.h1(color: c.ink)),
                      const SizedBox(height: Sp.x2),
                      Text(widget.title, textAlign: TextAlign.center, style: AllyType.body(color: c.muted)),
                      if (a?.status != null || widget.nextLine != null) ...[
                        const SizedBox(height: Sp.x3),
                        Text(
                          [if (a?.status != null) '${a!.name}: ${a.status}.', if (widget.nextLine != null) widget.nextLine!].join('\n'),
                          textAlign: TextAlign.center,
                          style: AllyType.small(color: c.faint),
                        ),
                      ],
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: Sp.x6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        AllyButton('Back to today', wide: true, onPressed: () => Navigator.of(context).pop()),
                        const SizedBox(height: Sp.x2),
                        Row(children: [
                          if (widget.canUndo) ...[
                            Expanded(
                              child: AllyButton('Undo',
                                  kind: AllyButtonKind.secondary,
                                  wide: true,
                                  onPressed: () => Navigator.of(context).pop(DoneChoice.undo)),
                            ),
                            const SizedBox(width: Sp.x2),
                          ],
                          Expanded(
                            child: AllyButton('Done for today',
                                kind: AllyButtonKind.ghost,
                                wide: true,
                                onPressed: () => Navigator.of(context).pop(DoneChoice.finishedForToday)),
                          ),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonePainter extends CustomPainter {
  final Color track, ring, tick;
  final double from, to, ringT, tickT;

  _DonePainter({
    required this.track,
    required this.ring,
    required this.tick,
    required this.from,
    required this.to,
    required this.ringT,
    required this.tickT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centre, r, p..color = track);
    final v = (from + (to - from) * ringT).clamp(0.0, 1.0);
    if (v > 0) {
      canvas.drawArc(Rect.fromCircle(center: centre, radius: r), -math.pi / 2, 2 * math.pi * v, false, p..color = ring);
    }
    if (tickT <= 0) return;
    // The tick, drawn along its length.
    final s = size.shortestSide / 120;
    final path = Path()
      ..moveTo(centre.dx - 18 * s, centre.dy + 2 * s)
      ..lineTo(centre.dx - 6 * s, centre.dy + 14 * s)
      ..lineTo(centre.dx + 18 * s, centre.dy - 13 * s);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * tickT),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tick,
    );
  }

  @override
  bool shouldRepaint(_DonePainter old) =>
      old.ringT != ringT || old.tickT != tickT || old.from != from || old.to != to || old.ring != ring || old.track != track;
}
