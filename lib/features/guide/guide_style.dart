import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ally's look (step 8, ADR 0021): the day as a shape, one thing as a sentence,
/// nothing that counts against you. Paper in the day, near-black at night.
/// Libre Franklin for everything you tap, Libre Caslon italic for Ally's voice.
///
/// Colours are getters because they follow the phone's light/dark setting;
/// [dark] is set once at the app root (see main.dart) and the tree is rebuilt
/// when it changes.
class G {
  static bool dark = false;

  static Color _p(int light, int night) => Color(dark ? night : light);

  static Color get bg => _p(0xFFF2F2EF, 0xFF111214);
  static Color get card => _p(0xFFF9F9F7, 0xFF1C1D20);
  static Color get ink => _p(0xFF15140F, 0xFFECE9E1);
  static Color get muted => _p(0xFF5B5A53, 0xFFA6A39A);
  static Color get line => _p(0xFFD9D8D1, 0xFF2A2B2E);
  static Color get soft => _p(0xFFE9E8E2, 0xFF1C1D20);
  static Color get tint => _p(0xFFE9E8E2, 0xFF1C1D20);
  static Color get tintInk => ink;
  static Color get good => _p(0xFF3E7F57, 0xFF6FB88A);
  static Color get goodSoft => _p(0xFFE1EBE3, 0xFF1F2B24);

  /// The one accent. Follows the Main area; until areas carry a colour it is this blue.
  static Color get accent => _p(0xFF2B44D0, 0xFF8FA2FF);

  /// Carried over from an earlier day. A warm brown, never red.
  static Color get carried => _p(0xFFA4642E, 0xFFD69A66);

  /// Text/icon colour on a filled ink button.
  static Color get onInk => _p(0xFFF2F2EF, 0xFF111214);

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

  static TextStyle display(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      GoogleFonts.libreFranklin(
          fontSize: size,
          fontWeight: w,
          color: color ?? ink,
          height: 1.08,
          letterSpacing: size >= 28 ? -1 : -0.4);

  static TextStyle text(double size, {Color? color, FontWeight w = FontWeight.w400, double height = 1.4}) =>
      GoogleFonts.libreFranklin(
          fontSize: size, fontWeight: w, color: color ?? ink, height: height);

  /// Ally's own voice: italic serif, used for the one sentence that matters.
  static TextStyle voice(double size, {Color? color}) => GoogleFonts.libreCaslonText(
      fontSize: size,
      fontStyle: FontStyle.italic,
      color: color ?? muted,
      height: size >= 28 ? 1.17 : 1.38,
      letterSpacing: size >= 28 ? -0.4 : 0);

  /// Small section label. Plain, no tracking, no capitals.
  static TextStyle label({Color? color}) =>
      GoogleFonts.libreFranklin(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? muted);
}

/// The primary button: filled ink, 6px corners, no shadow.
class GButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const GButton(this.label, {super.key, this.onTap, this.primary = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: primary ? G.ink : Colors.transparent,
          foregroundColor: primary ? G.onInk : G.muted,
          disabledBackgroundColor: (primary ? G.ink : Colors.transparent).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label, style: G.text(17, w: primary ? FontWeight.w700 : FontWeight.w500, color: primary ? G.onInk : G.muted)),
      ),
    );
  }
}

/// A thin hairline.
class GLine extends StatelessWidget {
  const GLine({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: G.line);
}

/// The day as a shape: one thin band per part of the day, the current one raised
/// and a marker at the minute it is now. Boundaries are the usual day (06, 9:30,
/// 19, 22) until the schedule itself is sent with the right-now answer.
class DayStrip extends StatelessWidget {
  final DateTime now;
  const DayStrip({super.key, required this.now});

  static const _parts = [
    ('MORNING', 6.0, 9.5, '06'),
    ('OFFICE', 9.5, 19.0, '9:30'),
    ('EVENING', 19.0, 22.0, '7 pm'),
    ('NIGHT', 22.0, 24.0, '10'),
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
        height: 22,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < _parts.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              flex: ((_parts[i].$3 - _parts[i].$2) * 10).round(),
              child: LayoutBuilder(builder: (_, c) {
                final p = _parts[i];
                final isNow = p.$1 == current;
                final frac = ((h - p.$2) / (p.$3 - p.$2)).clamp(0.0, 1.0);
                final past = h >= p.$3;
                return Stack(clipBehavior: Clip.none, alignment: Alignment.bottomLeft, children: [
                  Container(
                    height: isNow ? 8 : 4,
                    color: G.part(p.$1).withValues(alpha: isNow ? 1 : (past ? 0.35 : 0.6)),
                  ),
                  if (isNow) Positioned(left: c.maxWidth * frac, bottom: -6, child: Container(width: 2, height: 24, color: G.ink)),
                ]);
              }),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < _parts.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            flex: ((_parts[i].$3 - _parts[i].$2) * 10).round(),
            child: Text(_parts[i].$4, style: G.text(11, color: G.muted)),
          ),
        ],
      ]),
    ]);
  }
}

/// A list row: title, one muted line, and a plain-word action on the right.
/// Hairline above; no chevrons, no cards.
class GRow extends StatelessWidget {
  final String title;
  final String sub;
  final String action;
  final VoidCallback onTap;
  final bool last;
  const GRow(this.title, this.sub, this.onTap, {super.key, this.action = 'Open', this.last = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: G.line), bottom: last ? BorderSide(color: G.line) : BorderSide.none),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: G.text(16, w: FontWeight.w700)),
                if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 1), child: Text(sub, style: G.text(13, color: G.muted, height: 1.35))),
              ]),
            ),
            const SizedBox(width: 12),
            Text(action, style: G.text(13, color: G.muted)),
          ]),
        ),
      );
}

/// A small section heading between groups of rows.
class GHeading extends StatelessWidget {
  final String text;
  const GHeading(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 24, bottom: 6), child: Text(text, style: G.text(13, w: FontWeight.w700, color: G.muted)));
}
