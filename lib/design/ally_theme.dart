import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// Material themes built from the Ally tokens. New screens wrap themselves in
/// one of these (or the app root uses them once every screen is rebuilt).
class AllyTheme {
  AllyTheme._();

  static ThemeData dark() => _build(AllyColors.dark, Brightness.dark);
  static ThemeData light() => _build(AllyColors.light, Brightness.light);

  static ThemeData _build(AllyColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      // The main action is neutral: ink on background.
      primary: c.ink,
      onPrimary: c.bg,
      secondary: c.free,
      onSecondary: c.onFree,
      surface: c.bg,
      onSurface: c.ink,
      surfaceContainerHighest: c.raised,
      onSurfaceVariant: c.muted,
      outline: c.line,
      outlineVariant: c.line,
      error: c.warn,
      onError: c.bg,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: AllyType.textFamily,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [c],
    );
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Rad.button),
      borderSide: BorderSide(color: c.line),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AllyType.h2(color: c.ink),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: AllyType.body(color: c.faint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        border: field,
        enabledBorder: field,
        focusedBorder: field.copyWith(
            borderSide: BorderSide(color: c.ink, width: 1.5)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: const Color(0x8C040508),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
