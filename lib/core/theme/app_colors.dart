import 'package:flutter/material.dart';

/// Ally color tokens — Nocturne Sanctuary palette.
/// Fields are mutable statics — call [AppColors.apply] whenever mode/accent
/// changes, then rebuild the widget tree.
class AppColors {
  AppColors._();

  static bool isLight = false;

  // Surfaces
  static Color bg = const Color(0xFF111214);
  static Color surface1 = const Color(0xFF1B1C1E);
  static Color surface2 = const Color(0xFF1F2022);
  static Color surface3 = const Color(0xFF292A2C);
  static Color surface4 = const Color(0xFF343537);
  static Color inset = const Color(0xFF0D0E10);

  // Hairlines — Nocturne: deep rail #2A2B2E
  static Color line = const Color(0x332A2B2E);
  static Color line2 = const Color(0x55454652);
  static Color line3 = const Color(0x88454652);

  // Text — on-surface / on-surface-variant
  static Color tx = const Color(0xFFE3E2E4);
  static Color tx2 = const Color(0xFFC5C5D3);
  static Color tx3 = const Color(0xFF8F909D);
  static Color tx4 = const Color(0xFF454652);

  // Glass recipe (kept for compatibility; Nocturne is flat — avoid glass)
  static Color glassBg = const Color(0x941F2022);
  static Color glassBg2 = const Color(0xA8292A2C);
  static Color glassBorder = const Color(0x1AFFFFFF);

  // Accent (driven by AppAccent — defaults to Nocturne slate-indigo)
  static Color accent = const Color(0xFFB9C3FF);
  static Color accent2 = const Color(0xFF8FA2FF);
  static Color accentInk = const Color(0xFF0D267F);
  static Color accentSoft = const Color(0x21B9C3FF);
  static Color accentLine = const Color(0x59B9C3FF);
  static Color accentGlow = const Color(0x38B9C3FF);

  // Life-area hues (mode-independent)
  static const career = Color(0xFF8FA2FF);       // primary-container
  static const health = Color(0xFF92D5A7);       // secondary (sage)
  static const mind = Color(0xFFB9C3FF);         // primary
  static const finance = Color(0xFFFFB780);      // tertiary (ochre)
  static const relationships = Color(0xFFFFB4AB);
  static const creative = Color(0xFFE1975C);

  // Semantic
  static const danger = Color(0xFFFFB4AB);
  static const warn = Color(0xFFFFB780);
  static const ok = Color(0xFF92D5A7);

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
      bg = const Color(0xFFF2F2EF);
      surface1 = const Color(0xFFF9F9F7);
      surface2 = const Color(0xFFEFEFED);
      surface3 = const Color(0xFFE8E8E6);
      surface4 = const Color(0xFFDFDFDC);
      inset = const Color(0xFFF5F5F3);
      line = const Color(0x22000000);
      line2 = const Color(0x33000000);
      line3 = const Color(0x55000000);
      tx = const Color(0xFF15140F);
      tx2 = const Color(0xFF5B5A53);
      tx3 = const Color(0xFF8B8B82);
      tx4 = const Color(0xFFBBBBB0);
      glassBg = const Color(0x9EF9F9F7);
      glassBg2 = const Color(0xBDFFFFFF);
      glassBorder = const Color(0x14000000);
    } else {
      bg = const Color(0xFF111214);
      surface1 = const Color(0xFF1B1C1E);
      surface2 = const Color(0xFF1F2022);
      surface3 = const Color(0xFF292A2C);
      surface4 = const Color(0xFF343537);
      inset = const Color(0xFF0D0E10);
      line = const Color(0x332A2B2E);
      line2 = const Color(0x55454652);
      line3 = const Color(0x88454652);
      tx = const Color(0xFFE3E2E4);
      tx2 = const Color(0xFFC5C5D3);
      tx3 = const Color(0xFF8F909D);
      tx4 = const Color(0xFF454652);
      glassBg = const Color(0x941F2022);
      glassBg2 = const Color(0xA8292A2C);
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

  /// Nocturne Sanctuary default — Calm Slate-Indigo (#B9C3FF).
  static const nocturne = AppAccent(
    color: Color(0xFFB9C3FF),
    ink: Color(0xFF0D267F),
    soft: Color(0x21B9C3FF),
    line: Color(0x59B9C3FF),
    glow: Color(0x38B9C3FF),
  );

  /// All legacy accents remapped to Nocturne palette tokens.
  static const chartreuse = nocturne; // was chartreuse, now remapped

  static const teal = AppAccent(
    color: Color(0xFF92D5A7),
    ink: Color(0xFF00391E),
    soft: Color(0x2192D5A7),
    line: Color(0x5992D5A7),
    glow: Color(0x3892D5A7),
  );

  static const blue = AppAccent(
    color: Color(0xFF8FA2FF),
    ink: Color(0xFF1F348B),
    soft: Color(0x268FA2FF),
    line: Color(0x668FA2FF),
    glow: Color(0x478FA2FF),
  );

  static const purple = AppAccent(
    color: Color(0xFFB9C3FF),
    ink: Color(0xFF0D267F),
    soft: Color(0x26B9C3FF),
    line: Color(0x66B9C3FF),
    glow: Color(0x47B9C3FF),
  );

  static const orange = AppAccent(
    color: Color(0xFFFFB780),
    ink: Color(0xFF4E2600),
    soft: Color(0x26FFB780),
    line: Color(0x66FFB780),
    glow: Color(0x47FFB780),
  );

  static const all = [nocturne, teal, blue, purple, orange];

  static AppAccent fromHex(String? hex) {
    if (hex == null) return nocturne;
    final v = hex.toUpperCase().replaceAll('#', '');
    for (final a in all) {
      if (a.color.toARGB32().toRadixString(16).substring(2).toUpperCase() ==
          v) {
        return a;
      }
    }
    return nocturne;
  }
}
