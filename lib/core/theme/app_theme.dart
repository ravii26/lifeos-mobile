import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/guide/guide_style.dart';
import 'app_colors.dart';

/// Builds the Ally (Nocturne Sanctuary) theme.
/// Uses G.* colour tokens so that [G.dark] drives the entire visual palette.
/// The old [AppAccent] and font params are kept for compatibility with the
/// AppearanceCubit, but the primary surface/text colours are always pulled
/// from [G] (which follows the OS dark/light setting).
class AppTheme {
  AppTheme._();

  /// Resolves the /settings.font value to a Google Fonts text theme.
  static TextTheme _textTheme(String font, TextTheme base) =>
      GoogleFonts.instrumentSansTextTheme(base);

  /// Builds the theme from the CURRENT [G] palette.
  static ThemeData build(
      {AppAccent accent = AppAccent.nocturne,
      String font = 'libre',
      bool light = false}) {
    final brightness = light ? Brightness.light : Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: G.accent,
      onPrimary: G.bg,
      primaryContainer: G.accentStrong.withValues(alpha: 0.2),
      onPrimaryContainer: G.accent,
      secondary: G.good,
      onSecondary: G.bg,
      secondaryContainer: G.goodSoft,
      onSecondaryContainer: G.good,
      tertiary: G.carried,
      onTertiary: G.bg,
      surface: G.bg,
      onSurface: G.ink,
      surfaceContainerHighest: G.surfaceHigh,
      onSurfaceVariant: G.muted,
      outline: G.line,
      outlineVariant: G.lineSoft,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: G.bg,
      canvasColor: G.bg,
      splashColor: G.accent.withValues(alpha: 0.08),
      highlightColor: G.accent.withValues(alpha: 0.05),
    );

    return base.copyWith(
      textTheme: _textTheme(font, base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: G.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: G.faint, size: 22),
        titleTextStyle: GoogleFonts.instrumentSerif(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: G.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: G.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: G.lineSoft, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: G.card,
        hintStyle: TextStyle(color: G.faint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.line, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.line, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.accent, width: 1),
        ),
      ),
      dividerTheme:
          DividerThemeData(color: G.lineSoft, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: G.surfaceHigh,
        contentTextStyle: GoogleFonts.instrumentSans(
            fontSize: 13, color: G.ink),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: G.bg,
        selectedItemColor: G.accent,
        unselectedItemColor: G.faint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? G.accent : G.card),
        checkColor: WidgetStateProperty.all(G.bg),
        side: BorderSide(color: G.line, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}
