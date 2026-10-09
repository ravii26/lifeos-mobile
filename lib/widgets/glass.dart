import 'package:flutter/material.dart';

import '../features/guide/guide_style.dart';

/// Nocturne Sanctuary planar card (replaces frosted glass).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 4,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? G.card : null,
        gradient: gradient,
        borderRadius: r,
        border: Border.all(color: borderColor ?? G.lineSoft, width: 0.5),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// A plain surface card — Nocturne planar container.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 4,
    this.color,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? G.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? G.lineSoft, width: 0.5),
      ),
      child: child,
    );
  }
}
