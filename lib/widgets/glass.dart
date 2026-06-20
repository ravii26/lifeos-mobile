import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A frosted-glass container — the signature surface from m-ds.css `.glass`.
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
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final card = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: gradient == null ? AppColors.glassBg : null,
            gradient: gradient,
            borderRadius: r,
            border: Border.all(color: borderColor ?? AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// A plain (non-glass) surface card — m-ds.css `.m-card`.
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
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface1) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: child,
    );
  }
}
