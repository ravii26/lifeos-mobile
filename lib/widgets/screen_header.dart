import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import 'bits.dart';

/// Sticky-style screen header — `MHeader`.
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
          18, MediaQuery.of(context).padding.top + 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) Eyebrow(eyebrow!),
                const SizedBox(height: 3),
                Text(title,
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        height: 1.05,
                        color: AppColors.tx)),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                        fontSize: 13, color: AppColors.tx3, height: 1.4),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HeadButton(icon: Icons.grid_view_rounded, onTap: onMore),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: onMore,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.career],
                ),
              ),
              child: Center(
                child: Text(avatarInitial,
                    style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: const Color(0xFF0A0C08))),
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(icon, size: 18, color: AppColors.tx2),
        ),
      );
}

/// Section header row — `Sec`.
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
          Text(title,
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppColors.tx)),
          if (link != null)
            GestureDetector(
              onTap: onLink,
              child: Row(
                children: [
                  Text(link!,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tx3)),
                  Icon(Icons.chevron_right, size: 15, color: AppColors.tx3),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Back-style header for secondary (More) screens — `BackHead`.
class BackHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Color? color;
  const BackHeader(
      {super.key, required this.eyebrow, required this.title, this.color});

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
          Expanded(
            child: Column(
              children: [
                Eyebrow(eyebrow),
                const SizedBox(height: 2),
                Text(title,
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: color ?? AppColors.tx)),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
