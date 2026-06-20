import 'package:flutter/material.dart';

/// LifeOS color tokens — now a RUNTIME palette so the app can switch between
/// dark and light and re-skin the accent live.
///
/// Fields are mutable statics (not `const`). Call [AppColors.apply] whenever
/// the theme mode or accent changes, then rebuild the widget tree. Because the
/// values are read at build time, every (non-const) widget picks up the change.
class AppColors {
  AppColors._();

  static bool isLight = false;

  // Surfaces
  static Color bg = const Color(0xFF0A0B0D);
  static Color surface1 = const Color(0xFF101216);
  static Color surface2 = const Color(0xFF15181D);
  static Color surface3 = const Color(0xFF1C2027);
  static Color surface4 = const Color(0xFF242932);
  static Color inset = const Color(0xFF0C0E11);

  // Hairlines
  static Color line = const Color(0x11FFFFFF);
  static Color line2 = const Color(0x1CFFFFFF);
  static Color line3 = const Color(0x2EFFFFFF);

  // Text
  static Color tx = const Color(0xFFECEEF0);
  static Color tx2 = const Color(0xFFA6ABB3);
  static Color tx3 = const Color(0xFF6B717A);
  static Color tx4 = const Color(0xFF474C54);

  // Glass recipe (used by frosted surfaces)
  static Color glassBg = const Color(0x94141B22);
  static Color glassBg2 = const Color(0xA81C2027);
  static Color glassBorder = const Color(0x1AFFFFFF);

  // Accent (driven by the active AppAccent)
  static Color accent = const Color(0xFFC5F23F);
  static Color accent2 = const Color(0xFFD4FA66);
  static Color accentInk = const Color(0xFF11160A);
  static Color accentSoft = const Color(0x21C5F23F);
  static Color accentLine = const Color(0x59C5F23F);
  static Color accentGlow = const Color(0x38C5F23F);

  // Life-area hues (mode-independent)
  static const career = Color(0xFF4F8CFF);
  static const health = Color(0xFF2DD4A7);
  static const mind = Color(0xFFA884FF);
  static const finance = Color(0xFFC5F23F);
  static const relationships = Color(0xFFFF6B81);
  static const creative = Color(0xFFFF9D4D);

  // Semantic (mode-independent)
  static const danger = Color(0xFFFF5D62);
  static const warn = Color(0xFFFFB547);
  static const ok = Color(0xFF2DD4A7);

  /// Swap the whole palette for the given mode + accent.
  static void apply({required bool light, required AppAccent accent}) {
    isLight = light;
    AppColors.accent = accent.color;
    AppColors.accent2 = accent.color;
    AppColors.accentInk = accent.ink;
    AppColors.accentSoft = accent.soft;
    AppColors.accentLine = accent.line;
    AppColors.accentGlow = accent.glow;

    if (light) {
      bg = const Color(0xFFEEF0F3);
      surface1 = const Color(0xFFFFFFFF);
      surface2 = const Color(0xFFF4F5F8);
      surface3 = const Color(0xFFE9EBF0);
      surface4 = const Color(0xFFDFE2E9);
      inset = const Color(0xFFF7F8FA);
      line = const Color(0x140F141E);
      line2 = const Color(0x210F141E);
      line3 = const Color(0x330F141E);
      tx = const Color(0xFF14171C);
      tx2 = const Color(0xFF444B55);
      tx3 = const Color(0xFF767D88);
      tx4 = const Color(0xFFA3A9B3);
      glassBg = const Color(0x9EFFFFFF);
      glassBg2 = const Color(0xBDFFFFFF);
      glassBorder = const Color(0x140F141E);
    } else {
      bg = const Color(0xFF0A0B0D);
      surface1 = const Color(0xFF101216);
      surface2 = const Color(0xFF15181D);
      surface3 = const Color(0xFF1C2027);
      surface4 = const Color(0xFF242932);
      inset = const Color(0xFF0C0E11);
      line = const Color(0x11FFFFFF);
      line2 = const Color(0x1CFFFFFF);
      line3 = const Color(0x2EFFFFFF);
      tx = const Color(0xFFECEEF0);
      tx2 = const Color(0xFFA6ABB3);
      tx3 = const Color(0xFF6B717A);
      tx4 = const Color(0xFF474C54);
      glassBg = const Color(0x94141B22);
      glassBg2 = const Color(0xA81C2027);
      glassBorder = const Color(0x1AFFFFFF);
    }
  }
}

/// A selectable accent with its ink/soft/line/glow derivations.
class AppAccent {
  final Color color;
  final Color ink;
  final Color soft;
  final Color line;
  final Color glow;

  const AppAccent({
    required this.color,
    required this.ink,
    required this.soft,
    required this.line,
    required this.glow,
  });

  static const chartreuse = AppAccent(
    color: Color(0xFFC5F23F),
    ink: Color(0xFF11160A),
    soft: Color(0x21C5F23F),
    line: Color(0x59C5F23F),
    glow: Color(0x38C5F23F),
  );

  static const teal = AppAccent(
    color: Color(0xFF2DD4A7),
    ink: Color(0xFF04140F),
    soft: Color(0x212DD4A7),
    line: Color(0x592DD4A7),
    glow: Color(0x382DD4A7),
  );

  static const blue = AppAccent(
    color: Color(0xFF4F8CFF),
    ink: Color(0xFFFFFFFF),
    soft: Color(0x264F8CFF),
    line: Color(0x664F8CFF),
    glow: Color(0x474F8CFF),
  );

  static const purple = AppAccent(
    color: Color(0xFFA884FF),
    ink: Color(0xFFFFFFFF),
    soft: Color(0x26A884FF),
    line: Color(0x66A884FF),
    glow: Color(0x47A884FF),
  );

  static const orange = AppAccent(
    color: Color(0xFFFF9D4D),
    ink: Color(0xFF1A0F04),
    soft: Color(0x26FF9D4D),
    line: Color(0x66FF9D4D),
    glow: Color(0x47FF9D4D),
  );

  static const all = [chartreuse, teal, blue, purple, orange];

  static AppAccent fromHex(String? hex) {
    if (hex == null) return chartreuse;
    final v = hex.toUpperCase().replaceAll('#', '');
    for (final a in all) {
      if (a.color.toARGB32().toRadixString(16).substring(2).toUpperCase() ==
          v) {
        return a;
      }
    }
    return chartreuse;
  }
}
