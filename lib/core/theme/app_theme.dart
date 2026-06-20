import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds the LifeOS dark theme. Accent is injected so the runtime
/// "tweaks" (accent switching) can rebuild the theme.
class AppTheme {
  AppTheme._();

  /// Display / sans font — Hanken Grotesk per ds.css.
  static TextStyle sans([TextStyle? base]) =>
      GoogleFonts.hankenGrotesk(textStyle: base);

  /// Monospace — JetBrains Mono per ds.css.
  static TextStyle mono([TextStyle? base]) =>
      GoogleFonts.jetBrainsMono(textStyle: base);

  /// Resolves the /settings.font value to a Google Fonts text theme.
  static TextTheme _textTheme(String font, TextTheme base) => switch (font) {
        'mono' => GoogleFonts.jetBrainsMonoTextTheme(base),
        'serif' => GoogleFonts.loraTextTheme(base),
        _ => GoogleFonts.hankenGroteskTextTheme(base),
      };

  /// Builds the theme from the CURRENT [AppColors] palette (call
  /// [AppColors.apply] first). [light] selects the Material brightness.
  static ThemeData build(
      {AppAccent accent = AppAccent.chartreuse,
      String font = 'inter',
      bool light = false}) {
    final scheme = ColorScheme(
      brightness: light ? Brightness.light : Brightness.dark,
      primary: accent.color,
      onPrimary: accent.ink,
      secondary: accent.color,
      onSecondary: accent.ink,
      surface: AppColors.surface1,
      onSurface: AppColors.tx,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: light ? Brightness.light : Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashColor: accent.soft,
      highlightColor: accent.soft,
    );

    return base.copyWith(
      textTheme: _textTheme(font, base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inset,
        hintStyle: TextStyle(color: AppColors.tx4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: AppColors.line2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: AppColors.line2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: accent.line, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.line, thickness: 1),
    );
  }
}
