import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// A small line of recent readings, with the target as a faint dashed line.
/// It draws itself in from the left when it appears.
class TrendLine extends StatelessWidget {
  final List<double> points;

  /// Drawn as a faint dashed line when it is inside the range shown.
  final double? target;
  final Color color;
  final double height;
  final String? semanticLabel;

  const TrendLine({
    super.key,
    required this.points,
    required this.color,
    this.target,
    this.height = 44,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.of(context, Motion.d4),
          curve: Motion.ease,
          builder: (context, t, _) => CustomPaint(
            painter: _TrendPainter(points: points, target: target, color: color, guide: c.faint, track: c.line, draw: t),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> points;
  final double? target;
  final Color color, guide, track;
  final double draw;

  _TrendPainter({required this.points, required this.target, required this.color, required this.guide, required this.track, required this.draw});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      // Nothing yet: a quiet baseline, so the card keeps its shape.
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), Paint()
        ..color = track
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
      return;
    }
    var lo = points.reduce(math.min), hi = points.reduce(math.max);
    final t = target;
    // Include the target when it is close, so the line shows how far is left.
    if (t != null && (t - lo).abs() <= (hi - lo) * 2 + 1e-9) {
      lo = math.min(lo, t);
      hi = math.max(hi, t);
    }
    if (hi - lo < 1e-9) {
      hi += 1;
      lo -= 1;
    }
    const pad = 4.0;
    double y(double v) => pad + (size.height - pad * 2) * (1 - (v - lo) / (hi - lo));
    double x(int i) => points.length == 1 ? size.width / 2 : pad + (size.width - pad * 2) * i / (points.length - 1);

    if (t != null && t >= lo && t <= hi) {
      final dash = Paint()
        ..color = guide.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, y(t)), Offset(math.min(dx + 4, size.width), y(t)), dash);
      }
    }

    final path = Path()..moveTo(x(0), y(points[0]));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(x(i), y(points[i]));
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * draw, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
    if (draw >= 1) canvas.drawCircle(Offset(x(points.length - 1), y(points.last)), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.draw != draw || old.points != points || old.target != target || old.color != color;
}
