import 'package:flutter/material.dart';

import '../features/guide/guide_style.dart';
import 'bits.dart';

/// Sticky-style screen header — Nocturne editorial header.
class ScreenHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final Widget? subtitle;
  final String avatarInitial;
  final VoidCallback onMore;

  const ScreenHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    required this.avatarInitial,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) Eyebrow(eyebrow!),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: G.voice(24, color: G.ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle.merge(
                    style: G.label(size: 11.5, color: G.muted),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HeadButton(icon: Icons.grid_view_rounded, onTap: onMore),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onMore,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: G.accent.withValues(alpha: 0.15),
                border: Border.all(
                  color: G.accent.withValues(alpha: 0.35),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  avatarInitial,
                  style: G.text(14,
                      w: FontWeight.w700, color: G.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeadButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: G.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: G.lineSoft, width: 0.5),
          ),
          child: Icon(icon, size: 17, color: G.muted),
        ),
      );
}

/// Section header row.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? link;
  final VoidCallback? onLink;
  const SectionHeader(this.title, {super.key, this.link, this.onLink});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: G.label(size: 11, color: G.faint),
          ),
          if (link != null)
            GestureDetector(
              onTap: onLink,
              child: Row(
                children: [
                  Text(
                    link!,
                    style: G.label(size: 11, color: G.accent),
                  ),
                  Icon(Icons.chevron_right, size: 14, color: G.accent),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Back-style header for secondary screens.
class BackHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Color? color;
  final VoidCallback? onEdit;
  const BackHeader(
      {super.key,
      required this.eyebrow,
      required this.title,
      this.color,
      this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          14, MediaQuery.of(context).padding.top + 10, 14, 12),
      child: Row(
        children: [
          _HeadButton(
              icon: Icons.chevron_left,
              onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(eyebrow),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: G.voice(19, color: color ?? G.ink),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            _HeadButton(icon: Icons.edit_outlined, onTap: onEdit!),
        ],
      ),
    );
  }
}
