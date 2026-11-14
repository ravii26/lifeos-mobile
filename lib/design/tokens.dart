import 'package:flutter/material.dart';

/// Ally design tokens (reports/transformation/10 Final design.md, and
/// design/prototype/ally-final-design.html).
///
/// Colours live in a [ThemeExtension] so both themes work through
/// `Theme.of(context)`. Read them with `context.ac`.
///
/// The one rule that matters: [free] (marigold) means free time and its
/// Start button. Nothing else uses it.
@immutable
class AllyColors extends ThemeExtension<AllyColors> {
  /// Behind the app, outside the phone column on wide screens.
  final Color page;
  final Color bg;
  final Color surface;
  final Color raised;
  final Color line;

  final Color ink;
  final Color muted;
  final Color faint;

  /// Marigold: free time only.
  final Color free;

  /// Marigold that is readable as text on [bg].
  final Color freeInk;

  /// Text on a marigold fill.
  final Color onFree;
  final Color freeSoft;

  /// Ticks only.
  final Color done;

  /// A missed reminder or a destructive action only.
  final Color warn;
  final Color warnSoft;

  /// The palette a person's areas draw from, by position. Never tied to a
  /// named area: each person makes their own areas.
  final List<Color> areas;

  const AllyColors({
    required this.page,
    required this.bg,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.free,
    required this.freeInk,
    required this.onFree,
    required this.freeSoft,
    required this.done,
    required this.warn,
    required this.warnSoft,
    required this.areas,
  });

  static const dark = AllyColors(
    page: Color(0xFF060709),
    bg: Color(0xFF0D0E12),
    surface: Color(0xFF15171D),
    raised: Color(0xFF1E2129),
    line: Color(0xFF2B2F3A),
    ink: Color(0xFFF4F2ED),
    muted: Color(0xFFABAFBA),
    faint: Color(0xFF7D8290), // design had 757A87, which is 4.4:1 on bg; text needs 4.5
    free: Color(0xFFFFB23E),
    freeInk: Color(0xFFFFB23E),
    onFree: Color(0xFF1B1203),
    freeSoft: Color(0xFF2C2412),
    done: Color(0xFF5ED49A),
    warn: Color(0xFFFF9478),
    warnSoft: Color(0xFF2E1B16),
    areas: [
      Color(0xFFFF8255), // orange
      Color(0xFFA8DB5C), // lime
      Color(0xFF8C9BFF), // periwinkle
      Color(0xFFFF7EB6), // pink
      Color(0xFFE3B58A), // sand
      Color(0xFFC58BFF), // violet
      Color(0xFF58D0E8), // cyan
      Color(0xFF8B909C), // grey
    ],
  );

  static const light = AllyColors(
    page: Color(0xFFE4E2DC),
    bg: Color(0xFFF5F4F0),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFECEAE4),
    line: Color(0xFFD9D6CE),
    ink: Color(0xFF15161A),
    muted: Color(0xFF50545E),
    faint: Color(0xFF696D77), // design had 7B7F89, which is 3.6:1 on bg; text needs 4.5
    free: Color(0xFFF6A823),
    freeInk: Color(0xFF8F5400),
    onFree: Color(0xFF1B1203),
    freeSoft: Color(0xFFFBEBCB),
    done: Color(0xFF17875A),
    warn: Color(0xFFC4472A),
    warnSoft: Color(0xFFFBE5DE),
    areas: [
      Color(0xFFDD5527),
      Color(0xFF5C9412),
      Color(0xFF4F5FDD),
      Color(0xFFD23E86),
      Color(0xFFA06B32),
      Color(0xFF8B48DE),
      Color(0xFF0C8AAB),
      Color(0xFF6F747E),
    ],
  );

  /// The colour for a person's area at [index] in their list.
  Color area(int index) => areas[index.abs() % areas.length];

  @override
  AllyColors copyWith() => this;

  @override
  AllyColors lerp(ThemeExtension<AllyColors>? other, double t) {
    if (other is! AllyColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AllyColors(
      page: c(page, other.page),
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      raised: c(raised, other.raised),
      line: c(line, other.line),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      free: c(free, other.free),
      freeInk: c(freeInk, other.freeInk),
      onFree: c(onFree, other.onFree),
      freeSoft: c(freeSoft, other.freeSoft),
      done: c(done, other.done),
      warn: c(warn, other.warn),
      warnSoft: c(warnSoft, other.warnSoft),
      areas: [
        for (var i = 0; i < areas.length; i++)
          c(areas[i], other.areas[i % other.areas.length]),
      ],
    );
  }
}

extension AllyContext on BuildContext {
  /// Ally colours for the current theme.
  AllyColors get ac =>
      Theme.of(this).extension<AllyColors>() ?? AllyColors.dark;
}

/// Spacing steps. Use these, not new numbers.
class Sp {
  Sp._();
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 24.0;
  static const x6 = 32.0;

  /// Side padding of every screen.
  static const side = 18.0;
}

/// Corner radii.
class Rad {
  Rad._();
  static const tag = 8.0;
  static const chip = 14.0;
  static const button = 17.0;
  static const card = 22.0;
  static const sheet = 29.0;
}

/// Motion: four durations, two curves, one stagger.
class Motion {
  Motion._();

  /// Press feedback.
  static const d1 = Duration(milliseconds: 120);

  /// State changes: a chip, a switch, a colour.
  static const d2 = Duration(milliseconds: 220);

  /// Things arriving: a screen, a card, a toast.
  static const d3 = Duration(milliseconds: 380);

  /// Things that fill: rings, bars, the dial.
  static const d4 = Duration(milliseconds: 720);

  static const stagger = Duration(milliseconds: 45);

  static const ease = Cubic(0.2, 0.7, 0.2, 1);

  /// Overshoots a little; for things that settle into place.
  static const spring = Cubic(0.3, 1.36, 0.5, 1);

  /// True when the phone asks for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or no time at all when the phone asks for less motion.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
