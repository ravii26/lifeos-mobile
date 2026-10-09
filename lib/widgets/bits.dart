import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/guide/guide_style.dart';

/// Planar "add new" tile used at the foot of list sections.
class AddTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AddTile({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: G.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: G.lineSoft, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 16, color: G.accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: G.text(13.5,
                  w: FontWeight.w500, color: G.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uppercase mono eyebrow label — Nocturne Sanctuary label.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: G.label(
          size: 10.5,
          color: color ?? G.faint,
        ),
      );
}

/// Small planar badge.
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg ?? G.inset,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: bg == null ? G.lineSoft : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 5)],
            if (icon != null) ...[
              Icon(icon, size: 11, color: color ?? G.muted),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: G.label(
                size: 10,
                color: color ?? G.muted,
              ),
            ),
          ],
        ),
      );
}

/// Colored area dot.
class AreaDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool glow;
  const AreaDot(this.color, {super.key, this.size = 7, this.glow = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
}

/// Thin planar progress bar.
class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  const ProgressBar(this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Container(
        height: 3,
        decoration: BoxDecoration(
          color: G.inset,
          borderRadius: BorderRadius.circular(1.5),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color ?? G.accent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      );
}

/// Priority tag P1/P2/P3.
class PriorityTag extends StatelessWidget {
  final String label; // P1 | P2 | P3
  const PriorityTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (label) {
      'P1' => (G.carried, G.carried.withValues(alpha: 0.15)),
      'P2' => (G.accent, G.accent.withValues(alpha: 0.15)),
      _ => (G.faint, G.inset),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: G.lineSoft, width: 0.5),
      ),
      child: Text(
        label,
        style: G.label(size: 9.5, color: fg),
      ),
    );
  }
}

/// Segmented control.
class SegmentedControl<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  const SegmentedControl({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  }) : assert(values.length == labels.length);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: G.inset,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: G.lineSoft, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < values.length; i++)
              GestureDetector(
                onTap: () => onChanged(values[i]),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: values[i] == selected
                        ? G.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    labels[i],
                    style: G.text(
                      12,
                      w: values[i] == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: values[i] == selected ? G.accent : G.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Toggle switch.
class ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ToggleSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        activeColor: G.accent,
        onChanged: onChanged,
      );
}

/// Circular score ring — Donut.
class Donut extends StatelessWidget {
  final double value; // 0..100
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;
  const Donut({
    super.key,
    required this.value,
    this.size = 60,
    this.stroke = 4,
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
      ..color = G.lineSoft;
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
