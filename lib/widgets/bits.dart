import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// Uppercase mono eyebrow label — `.m-eyebrow`.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
          color: color ?? AppColors.tx3,
        ),
      );
}

/// Small mono pill — `.m-chip`.
class Chip3 extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? bg;
  final IconData? icon;
  final Widget? leading;
  const Chip3(this.text,
      {super.key, this.color, this.bg, this.icon, this.leading});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg ?? AppColors.surface3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: bg == null ? AppColors.line : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 5)],
            if (icon != null) ...[
              Icon(icon, size: 11, color: color ?? AppColors.tx2),
              const SizedBox(width: 5),
            ],
            Text(text,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    letterSpacing: .2,
                    color: color ?? AppColors.tx2)),
          ],
        ),
      );
}

/// Colored area dot — `.adot`.
class AreaDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool glow;
  const AreaDot(this.color, {super.key, this.size = 8, this.glow = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? [BoxShadow(color: color, blurRadius: 8, spreadRadius: 0)]
              : null,
        ),
      );
}

/// Thin progress bar — `.m-bar`.
class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  const ProgressBar(this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 6,
          backgroundColor: AppColors.surface3,
          valueColor:
              AlwaysStoppedAnimation(color ?? AppColors.accent),
        ),
      );
}

/// Priority tag P1/P2/P3 — `.pri`.
class PriorityTag extends StatelessWidget {
  final String label; // P1 | P2 | P3
  const PriorityTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (label) {
      'P1' => (const Color(0xFFFF8A8A), const Color(0x29FF5D62)),
      'P2' => (AppColors.warn, const Color(0x29FFB547)),
      _ => (AppColors.tx3, AppColors.surface3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Circular score ring — `Donut`.
class Donut extends StatelessWidget {
  final double value; // 0..100
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;
  const Donut({
    super.key,
    required this.value,
    this.size = 66,
    this.stroke = 6,
    required this.color,
    this.center,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(value / 100, stroke, color),
          child: Center(child: center),
        ),
      );
}

class _DonutPainter extends CustomPainter {
  final double fraction;
  final double stroke;
  final Color color;
  _DonutPainter(this.fraction, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.surface3;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * fraction.clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.fraction != fraction || old.color != color;
}
