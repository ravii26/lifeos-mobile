import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// Ally's one motif: rings. The day is a 24-hour dial, a life is a wheel,
/// progress and a focus session are rings that fill.

const _top = -math.pi / 2;
const _turn = 2 * math.pi;

/// Progress for one thing: this week against the plan, or a focus session.
class ProgressRing extends StatelessWidget {
  /// 0 to 1.
  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  /// Shows a tick in the middle when the ring is full.
  final bool tickWhenFull;
  final String? semanticLabel;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 44,
    this.stroke = 5,
    this.child,
    this.tickWhenFull = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final v = value.clamp(0.0, 1.0).toDouble();
    final full = v >= 1 && tickWhenFull;
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: v),
        duration: Motion.of(context, Motion.d4),
        curve: Motion.ease,
        builder: (context, t, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
                value: t, color: full ? c.done : color, track: c.raised, stroke: stroke),
            child: Center(
              child: full
                  ? Icon(Icons.check_rounded, color: c.done, size: size * 0.42)
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter(
      {required this.value,
      required this.color,
      required this.track,
      required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.shortestSide - stroke) / 2;
    final centre = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centre, r, p..color = track);
    if (value > 0) {
      canvas.drawArc(Rect.fromCircle(center: centre, radius: r), _top,
          _turn * value, false, p..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

enum DayPartKind {
  /// Sleep, office, commute: time that is spoken for. Drawn thin and dim.
  fixed,

  /// Something planned, in its area's colour.
  planned,

  /// Free time. Marigold, with a slow glow.
  free,
}

/// One stretch of the day on the dial, in minutes from midnight.
/// A stretch may run past midnight ([end] smaller than [start]).
class DayPart {
  final int start;
  final int end;
  final DayPartKind kind;

  /// Used for [DayPartKind.planned].
  final Color? color;

  const DayPart(this.start, this.end, this.kind, {this.color});

  int get minutes => end >= start ? end - start : 1440 - start + end;
}

/// The 24 hours as a ring: midnight at the top, noon at the bottom.
class DayDial extends StatefulWidget {
  final List<DayPart> parts;

  /// Minutes from midnight.
  final int now;

  /// What sits in the middle: usually the free minutes and a line of text.
  final Widget? child;
  final double maxSize;
  final String? semanticLabel;

  /// Tapping a free part that is not over yet. Screen readers get the same
  /// action on the whole dial, for the next free part, described by [tapHint].
  final ValueChanged<DayPart>? onTapFree;
  final String? tapHint;

  const DayDial({
    super.key,
    required this.parts,
    required this.now,
    this.child,
    this.maxSize = 300,
    this.semanticLabel,
    this.onTapFree,
    this.tapHint,
  });

  @override
  State<DayDial> createState() => _DayDialState();
}

class _DayDialState extends State<DayDial> with TickerProviderStateMixin {
  late final AnimationController _draw =
      AnimationController(vsync: this, duration: Motion.d4);
  late final AnimationController _halo = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = Motion.reduced(context);
    if (!_started) {
      _started = true;
      reduced ? _draw.value = 1 : _draw.forward();
    }
    if (reduced) {
      _halo.stop();
      _halo.value = 0.5;
    } else if (!_halo.isAnimating) {
      _halo.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final onTap = widget.onTapFree;
    final next = onTap == null ? null : nextFreePart(widget.parts, widget.now);
    return Semantics(
      label: widget.semanticLabel,
      hint: next == null ? null : widget.tapHint,
      container: true,
      onTap: next == null ? null : () => onTap!(next),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxSize),
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: onTap == null
                    ? null
                    : (d) {
                        final part = freePartAt(widget.parts, widget.now, d.localPosition, box.biggest);
                        if (part != null) onTap(part);
                      },
                child: _dial(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dial(AllyColors c) => AnimatedBuilder(
              animation: Listenable.merge([_draw, _halo]),
              builder: (context, child) => CustomPaint(
                painter: _DialPainter(
                  parts: widget.parts,
                  now: widget.now,
                  colors: c,
                  draw: Motion.ease.transform(_draw.value),
                  halo: Curves.easeInOut.transform(_halo.value),
                  tickStyle: AllyType.num(color: c.faint, size: 11),
                  textScaler: MediaQuery.textScalerOf(context),
                ),
                child: child,
              ),
              child: FractionallySizedBox(
                widthFactor: 0.56,
                heightFactor: 0.56,
                // Shrinks to fit at large text sizes rather than clipping.
                child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
              ),
            );
}

// The dial's ring sits here inside its square (see _DialPainter.paint).
double _dialRadius(Size size) => size.shortestSide / 2 - _DialPainter._band / 2 - 8;

bool _contains(DayPart p, int minute) =>
    p.end >= p.start ? minute >= p.start && minute < p.end : minute >= p.start || minute < p.end;

bool _over(DayPart p, int now) => p.end >= p.start && p.end <= now;

/// The free part of the day under a tap on the dial, if it is not over yet.
/// A tap counts when it lands on the ring or close to it (fingers are wide).
DayPart? freePartAt(List<DayPart> parts, int now, Offset local, Size size) {
  const reach = 24.0;
  final d = local - size.center(Offset.zero);
  if ((d.distance - _dialRadius(size)).abs() > reach) return null;
  var a = math.atan2(d.dy, d.dx) - _top;
  a = (a % _turn + _turn) % _turn;
  final minute = (a / _turn * 1440).floor() % 1440;
  for (final p in parts) {
    if (p.kind == DayPartKind.free && !_over(p, now) && _contains(p, minute)) return p;
  }
  return null;
}

/// The free part someone is in, or the next one today.
DayPart? nextFreePart(List<DayPart> parts, int now) {
  DayPart? best;
  for (final p in parts) {
    if (p.kind != DayPartKind.free || _over(p, now)) continue;
    if (_contains(p, now)) return p;
    if (p.start > now && (best == null || p.start < best.start)) best = p;
  }
  return best;
}

class _DialPainter extends CustomPainter {
  final List<DayPart> parts;
  final int now;
  final AllyColors colors;
  final double draw;
  final double halo;
  final TextStyle tickStyle;
  final TextScaler textScaler;

  _DialPainter({
    required this.parts,
    required this.now,
    required this.colors,
    required this.draw,
    required this.halo,
    required this.tickStyle,
    required this.textScaler,
  });

  static const _band = 18.0;

  double _angle(num minutes) => _top + _turn * (minutes / 1440);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    // Leave room outside the ring for the glow and the hand's knob.
    final r = size.shortestSide / 2 - _band / 2 - 8;
    final rect = Rect.fromCircle(center: centre, radius: r);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
        centre,
        r,
        p
          ..strokeWidth = _band
          ..color = colors.raised);

    for (final part in parts) {
      // A small gap so rounded ends of neighbours do not overlap.
      const gap = 0.035;
      final full = _turn * (part.minutes / 1440);
      final sweep = math.max(0.0, full - gap) * draw;
      if (sweep <= 0) continue;
      final start = _angle(part.start) + gap / 2;
      // Past time is dimmed; what is still ahead stays bright.
      final past = _isPast(part);
      switch (part.kind) {
        case DayPartKind.fixed:
          canvas.drawArc(
              rect,
              start,
              sweep,
              false,
              p
                ..strokeWidth = 6
                ..color = colors.line);
        case DayPartKind.planned:
          canvas.drawArc(
              rect,
              start,
              sweep,
              false,
              p
                ..strokeWidth = _band
                ..color = (part.color ?? colors.muted)
                    .withValues(alpha: past ? 0.3 : 1));
        case DayPartKind.free:
          if (!past) {
            canvas.drawArc(
                rect,
                start,
                sweep,
                false,
                p
                  ..strokeWidth = 30
                  ..color =
                      colors.free.withValues(alpha: 0.10 + 0.16 * halo));
          }
          canvas.drawArc(
              rect,
              start,
              sweep,
              false,
              p
                ..strokeWidth = _band
                ..color = colors.free.withValues(alpha: past ? 0.3 : 1));
      }
    }

    // Hour marks inside the ring.
    const labels = {0: '12am', 360: '6am', 720: '12pm', 1080: '6pm'};
    for (final e in labels.entries) {
      final tp = TextPainter(
        text: TextSpan(text: e.value, style: tickStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final a = _angle(e.key);
      final at = centre +
          Offset(math.cos(a), math.sin(a)) * (r - _band / 2 - 6 - tp.height) -
          Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, at);
    }

    // The hand: where now is.
    final a = _angle(now);
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
        centre + dir * (r - _band / 2 - 3),
        centre + dir * (r + _band / 2 + 3),
        Paint()
          ..color = colors.ink
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    final knob = centre + dir * (r + _band / 2 + 3);
    canvas.drawCircle(knob, 5.5, Paint()..color = colors.bg);
    canvas.drawCircle(knob, 4, Paint()..color = colors.ink);
  }

  bool _isPast(DayPart part) {
    if (part.end >= part.start) return part.end <= now;
    // Runs past midnight (usually sleep): part of it is always still ahead.
    return false;
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.draw != draw ||
      old.halo != halo ||
      old.now != now ||
      old.colors != colors ||
      old.parts != parts ||
      old.textScaler != textScaler;
}

/// One area on the life wheel.
class WheelSpoke {
  final String label;
  final Color color;

  /// This week's progress, 0 to 1.
  final double value;

  const WheelSpoke(this.label, this.color, this.value);
}

/// One spoke per area, as long as this week's progress. Short spokes are the
/// areas that have had less of you.
class LifeWheel extends StatefulWidget {
  final List<WheelSpoke> spokes;
  final ValueChanged<int>? onTap;
  final Widget? child;
  final double maxSize;

  const LifeWheel({
    super.key,
    required this.spokes,
    this.onTap,
    this.child,
    this.maxSize = 240,
  });

  @override
  State<LifeWheel> createState() => _LifeWheelState();
}

class _LifeWheelState extends State<LifeWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: Motion.d4 +
          const Duration(milliseconds: 55) * math.max(0, widget.spokes.length - 1));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    Motion.reduced(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int? _hit(Offset local, Size size) {
    final n = widget.spokes.length;
    if (n == 0) return null;
    final d = local - size.center(Offset.zero);
    if (d.distance < size.shortestSide * 0.14) return null;
    var a = math.atan2(d.dy, d.dx) - _top;
    a = (a % _turn + _turn) % _turn;
    return ((a + _turn / n / 2) / (_turn / n)).floor() % n;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final summary = [
      for (final s in widget.spokes) '${s.label} ${(s.value * 100).round()}%'
    ].join(', ');
    return Semantics(
      label: 'This week by area: $summary',
      container: true,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxSize),
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onTap == null
                    ? null
                    : (d) {
                        final i = _hit(d.localPosition, box.biggest);
                        if (i != null) widget.onTap!(i);
                      },
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) => CustomPaint(
                    painter: _WheelPainter(
                      spokes: widget.spokes,
                      track: c.raised,
                      elapsed: _c.value * _c.duration!.inMilliseconds,
                    ),
                    child: child,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.28,
                    heightFactor: 0.28,
                    child: Center(child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<WheelSpoke> spokes;
  final Color track;

  /// Milliseconds since the wheel appeared.
  final double elapsed;

  _WheelPainter(
      {required this.spokes, required this.track, required this.elapsed});

  @override
  void paint(Canvas canvas, Size size) {
    final n = spokes.length;
    if (n == 0) return;
    final centre = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 8;
    final inner = size.shortestSide * 0.19;
    // Thinner spokes when there are many areas, so they never touch.
    final width = math.min(15.0, (_turn * inner / n) * 0.7);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final a = _top + _turn * i / n;
      final dir = Offset(math.cos(a), math.sin(a));
      final from = centre + dir * inner;
      canvas.drawLine(from, centre + dir * outer, p..color = track);
      final t = ((elapsed - 55 * i - 80) / Motion.d4.inMilliseconds)
          .clamp(0.0, 1.0)
          .toDouble();
      final v = spokes[i].value.clamp(0.0, 1.0) * Motion.ease.transform(t);
      if (v > 0) {
        canvas.drawLine(from, centre + dir * (inner + (outer - inner) * v),
            p..color = spokes[i].color);
      }
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.elapsed != elapsed || old.spokes != spokes || old.track != track;
}
