import 'package:flutter/material.dart';

/// Ally type: Schibsted Grotesk for display, Geist for text, Geist Mono for
/// times and durations. Scale: 30, 21, 16, 14, 12.
///
/// All three are bundled under `assets/fonts/` as variable fonts, so nothing
/// is downloaded at runtime. Weight is set on the font's own axis as well as
/// through [FontWeight], which is what a variable font needs.
class AllyType {
  AllyType._();

  static const displayFamily = 'Schibsted Grotesk';
  static const textFamily = 'Geist';
  static const monoFamily = 'Geist Mono';

  static List<FontVariation> _wght(FontWeight w) =>
      [FontVariation.weight(w.value.toDouble())];

  static TextStyle _display(
          double size, FontWeight w, double tracking, double height,
          Color? color) =>
      TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        fontWeight: w,
        fontVariations: _wght(w),
        letterSpacing: tracking * size,
        height: height,
        color: color,
      );

  /// Greeting or page title.
  static TextStyle h1({Color? color}) =>
      _display(30, FontWeight.w700, -0.022, 1.08, color);

  /// Card or sheet title.
  static TextStyle h2({Color? color}) =>
      _display(21, FontWeight.w700, -0.015, 1.18, color);

  /// The big number: free minutes, a timer.
  static TextStyle big({Color? color, double size = 37}) => _display(
          size, FontWeight.w800, -0.03, 1, color)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Everything you read and tap.
  static TextStyle body({Color? color, FontWeight w = FontWeight.w400}) =>
      TextStyle(
          fontFamily: textFamily,
          fontSize: 16,
          fontWeight: w,
          fontVariations: _wght(w),
          height: 1.45,
          color: color);

  static TextStyle small({Color? color, FontWeight w = FontWeight.w400}) =>
      TextStyle(
          fontFamily: textFamily,
          fontSize: 14,
          fontWeight: w,
          fontVariations: _wght(w),
          height: 1.4,
          color: color);

  /// Section label, in capitals.
  static TextStyle eyebrow({Color? color}) => TextStyle(
      fontFamily: textFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontVariations: _wght(FontWeight.w600),
      letterSpacing: 12 * 0.09,
      height: 1.3,
      color: color);

  /// Times and durations, so columns line up.
  static TextStyle num({Color? color, double size = 14}) => TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: const ['monospace'],
      fontSize: size,
      fontWeight: FontWeight.w500,
      fontVariations: _wght(FontWeight.w500),
      letterSpacing: -0.02 * size,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color);
}
