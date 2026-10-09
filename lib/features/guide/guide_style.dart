import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ally's look (step 8, ADR 0021): the day as a shape, one thing as a sentence,
/// nothing that counts against you. Paper in the day, near-black at night.
/// Libre Franklin for everything you tap, Libre Caslon italic for Ally's voice.
///
/// Colours are getters because they follow the phone's light/dark setting;
/// [dark] is set once at the app root (see main.dart) and the tree is rebuilt
/// when it changes.
///
/// Nocturne Sanctuary design system — see stitch_ally_personal_assistant_design/.
class G {
  static bool dark = false;

  static Color _p(int light, int night) => Color(dark ? night : light);

  // — Surfaces —
  /// Base canvas: #111214 (night) / #F2F2EF (day)
  static Color get bg => _p(0xFFF2F2EF, 0xFF111214);

  /// Slightly raised surface: surface-container-low
  static Color get card => _p(0xFFF9F9F7, 0xFF1B1C1E);

  /// surface-container
  static Color get surface => _p(0xFFEFEFED, 0xFF1F2022);

  /// surface-container-high
  static Color get surfaceHigh => _p(0xFFE8E8E6, 0xFF292A2C);

  /// surface-container-lowest
  static Color get inset => _p(0xFFF5F5F3, 0xFF0D0E10);

  // — Text —
  /// on-surface: #ECE9E1 (night) / #15140F (day)
  static Color get ink => _p(0xFF15140F, 0xFFE3E2E4);

  /// on-surface-variant: muted secondary text
  static Color get muted => _p(0xFF5B5A53, 0xFFC5C5D3);

  /// outline: even more muted
  static Color get faint => _p(0xFF8B8B82, 0xFF8F909D);

  // — Hairlines —
  /// outline-variant hairline: #2A2B2E (night)
  static Color get line => _p(0xFFD9D8D1, 0xFF454652);

  /// Softer hairline for section dividers
  static Color get lineSoft => _p(0xFFE9E8E2, 0xFF2A2B2E);

  // — Semantic —
  /// Calm Slate-Indigo — primary accent: #8FA2FF
  static Color get accent => _p(0xFF2B44D0, 0xFFB9C3FF);

  /// Primary container (slightly stronger): #8FA2FF
  static Color get accentStrong => _p(0xFF2B44D0, 0xFF8FA2FF);

  /// Sage Canopy — completed/resolved: #92D5A7 (secondary)
  static Color get good => _p(0xFF3E7F57, 0xFF92D5A7);

  /// Sage background: secondary-container
  static Color get goodSoft => _p(0xFFE1EBE3, 0xFF07522E);

  /// Carried-Over Ochre — deferred/carried: #FFBB80 (tertiary)
  static Color get carried => _p(0xFFA4642E, 0xFFFFB780);

  /// The ink colour on accent-filled buttons (on-primary)
  static Color get onInk => _p(0xFFF2F2EF, 0xFF111214);

  // — Backward-compatibility aliases (old G getters used across the codebase) —
  /// Alias for [card] — slightly raised surface.
  static Color get soft => card;
  /// Alias for [card] — tinted background surface.
  static Color get tint => card;
  /// Alias for [ink] — ink on tinted surface.
  static Color get tintInk => ink;


  /// Parts of the day.
  static Color part(String block) => switch (block) {
        'MORNING' => const Color(0xFFC28A2C),
        'COMMUTE' => const Color(0xFF7C8A5A),
        'OFFICE' => const Color(0xFF5E6E80),
        'GYM' => const Color(0xFFB0533C),
        'EVENING' => const Color(0xFF5C55B5),
        'NIGHT' => const Color(0xFF4A5282),
        _ => const Color(0xFF8A8980),
      };

  // — Typography helpers —

  /// Libre Caslon Text (italic) — Ally's voice for headlines.
  static TextStyle display(double size,
          {Color? color, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.libreCaslonText(
          fontSize: size,
          fontWeight: w,
          fontStyle: FontStyle.italic,
          color: color ?? ink,
          height: size >= 28 ? 1.17 : 1.35,
          letterSpacing: size >= 28 ? -0.015 * size : 0);

  /// Libre Franklin — system text, tasks, labels, action targets.
  static TextStyle text(double size,
          {Color? color,
          FontWeight w = FontWeight.w400,
          double height = 1.5,
          double letterSpacing = 0}) =>
      GoogleFonts.libreFranklin(
          fontSize: size,
          fontWeight: w,
          color: color ?? ink,
          height: height,
          letterSpacing: letterSpacing);

  /// Ally's own voice: italic serif, used for the one sentence that matters.
  static TextStyle voice(double size, {Color? color}) =>
      GoogleFonts.libreCaslonText(
          fontSize: size,
          fontStyle: FontStyle.italic,
          color: color ?? muted,
          height: size >= 28 ? 1.17 : 1.4,
          letterSpacing: 0);

  /// Small label — Libre Franklin, 500 weight, 0.04em tracking.
  static TextStyle label(
          {double size = 12,
          Color? color,
          FontWeight w = FontWeight.w500,
          double letterSpacing = 0.04}) =>
      GoogleFonts.libreFranklin(
          fontSize: size,
          fontWeight: w,
          color: color ?? faint,
          height: 1.2,
          letterSpacing: size * letterSpacing);

  /// Large numeral: light weight, tight tracking.
  static TextStyle numeral(double size, {Color? color}) =>
      GoogleFonts.libreFranklin(
          fontSize: size,
          fontWeight: FontWeight.w300,
          color: color ?? ink,
          height: 1.17,
          letterSpacing: -0.03 * size);
}

// ─── Shared Components ────────────────────────────────────────────────────────

/// The primary button: filled ink, 6px corners, no shadow.
class GButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;
  const GButton(this.label,
      {super.key, this.onTap, this.primary = true, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: primary
              ? G.accentStrong.withValues(alpha: 0.18)
              : Colors.transparent,
          foregroundColor: primary ? G.accent : G.muted,
          side: BorderSide(
              color: primary
                  ? G.accentStrong.withValues(alpha: 0.3)
                  : G.line.withValues(alpha: 0.5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: primary ? G.accent : G.muted),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: G.text(15,
                  w: FontWeight.w500, color: primary ? G.accent : G.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin hairline — ink sinking into dark paper.
class GLine extends StatelessWidget {
  final double opacity;
  const GLine({super.key, this.opacity = 1});
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: G.lineSoft.withValues(alpha: opacity));
}

/// Top app bar — Nocturne editorial style.
/// Bedtime icon or back arrow + title (italic serif) + subtitle, trailing slot.
class GTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final bool showBack;

  const GTopBar(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.leading,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: G.bg,
        border:
            Border(bottom: BorderSide(color: G.lineSoft, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Leading: back button or bedtime icon in accent
                if (leading != null)
                  leading!
                else if (showBack || Navigator.of(context).canPop())
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, size: 20, color: G.ink),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  Icon(Icons.bedtime_outlined, size: 20, color: G.accent),
                const SizedBox(width: 10),
                // Title + subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: G.voice(15.5,
                              color: G.ink)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: G.label(size: 11, color: G.faint)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal reassurance status capsule — a hairline border, no fill.
/// "Sab shaant hai. Rest now."
class GStatusCapsule extends StatelessWidget {
  final String text;
  final String? trailingText;
  const GStatusCapsule(this.text, {super.key, this.trailingText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: G.inset.withValues(alpha: 0.5),
        border: Border.all(color: G.lineSoft),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: G.good)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: G.voice(13.5, color: G.muted)),
          ),
          if (trailingText != null)
            Text(trailingText!,
                style: G.label(size: 11, color: G.faint)),
        ],
      ),
    );
  }
}

/// Ally's voice whisper — left accent bar, italic serif, no card boundary.
class GVoiceCard extends StatelessWidget {
  final String text;
  final String? meta;
  const GVoiceCard(this.text, {super.key, this.meta});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 2,
          height: 60,
          decoration: BoxDecoration(
              color: G.accent.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(1))),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$text"',
                style: G.voice(15,
                    color: G.muted)),
            if (meta != null) ...[
              const SizedBox(height: 4),
              Text(meta!, style: G.label(size: 11, color: G.faint)),
            ],
          ],
        ),
      ),
    ]);
  }
}

/// The day as a shape: one thin band per part of the day, the current one raised
/// and a marker at the minute it is now. Boundaries are the usual day (06, 9:30,
/// 19, 22) until the schedule itself is sent with the right-now answer.
class DayStrip extends StatelessWidget {
  final DateTime now;
  const DayStrip({super.key, required this.now});

  static const _parts = [
    ('MORNING', 6.0, 9.5, 'Subah'),
    ('OFFICE', 9.5, 19.0, 'Dopahar'),
    ('EVENING', 19.0, 22.0, 'Shaam'),
    ('NIGHT', 22.0, 24.0, 'Raat'),
  ];

  static String partOf(DateTime t) {
    final h = t.hour + t.minute / 60;
    for (final p in _parts) {
      if (h >= p.$2 && h < p.$3) return p.$1;
    }
    return 'NIGHT';
  }

  static String partName(String p) => switch (p) {
        'MORNING' => 'Morning',
        'OFFICE' => 'Office',
        'EVENING' => 'Evening',
        _ => 'Night',
      };

  @override
  Widget build(BuildContext context) {
    final h = now.hour + now.minute / 60;
    final current = partOf(now);
    return Column(children: [
      SizedBox(
        height: 6,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < _parts.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: ((_parts[i].$3 - _parts[i].$2) * 10).round(),
              child: LayoutBuilder(builder: (_, c) {
                final p = _parts[i];
                final isNow = p.$1 == current;
                final frac =
                    ((h - p.$2) / (p.$3 - p.$2)).clamp(0.0, 1.0);
                final past = h >= p.$3;
                return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomLeft,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isNow
                              ? G.accentStrong.withValues(alpha: 0.7)
                              : G.part(p.$1).withValues(
                                  alpha: past ? 0.25 : 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (isNow)
                        Positioned(
                          left: (c.maxWidth * frac).clamp(0.0,
                              c.maxWidth - 8).toDouble(),
                          bottom: -3,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: G.accent,
                            ),
                          ),
                        ),
                    ]);
              }),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < _parts.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            flex: ((_parts[i].$3 - _parts[i].$2) * 10).round(),
            child: Text(_parts[i].$4,
                style: G.label(
                    size: 10,
                    color: _parts[i].$1 == current
                        ? G.accent
                        : G.faint)),
          ),
        ],
      ]),
    ]);
  }
}

/// A list row: title, one muted line, and a plain-word action on the right.
/// Hairline below; no chevrons, no cards.
class GRow extends StatelessWidget {
  final String title;
  final String sub;
  final String action;
  final VoidCallback onTap;
  final bool last;
  const GRow(this.title, this.sub, this.onTap,
      {super.key, this.action = 'Open', this.last = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: G.lineSoft, width: 0.5),
                bottom: last
                    ? BorderSide(color: G.lineSoft, width: 0.5)
                    : BorderSide.none),
          ),
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: G.text(15, w: FontWeight.w500)),
                    if (sub.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(sub,
                              style: G.text(13,
                                  color: G.muted, height: 1.4))),
                  ]),
            ),
            const SizedBox(width: 12),
            Text(action,
                style: G.label(size: 12, color: G.accent)),
          ]),
        ),
      );
}

/// A small section heading between groups of rows.
class GHeading extends StatelessWidget {
  final String text;
  const GHeading(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 6),
      child: Text(text, style: G.label(size: 11, color: G.faint)));
}

/// Folded accordion section — Nocturne Plan screen pattern.
class GFoldSection extends StatefulWidget {
  final Widget header;
  final Widget content;
  final bool initiallyExpanded;

  const GFoldSection({
    super.key,
    required this.header,
    required this.content,
    this.initiallyExpanded = false,
  });

  @override
  State<GFoldSection> createState() => _GFoldSectionState();
}

class _GFoldSectionState extends State<GFoldSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expand;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyExpanded;
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
        value: _open ? 1 : 0);
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: G.inset.withValues(alpha: 0.5),
        border: Border.all(color: G.lineSoft, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Expanded(child: widget.header),
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(_expand),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: G.faint),
                ),
              ]),
            ),
          ),
          SizeTransition(
            sizeFactor: _expand,
            child: Column(children: [
              Container(height: 0.5, color: G.lineSoft),
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: widget.content),
            ]),
          ),
        ],
      ),
    );
  }
}
