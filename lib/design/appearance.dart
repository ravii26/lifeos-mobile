import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ally_theme.dart';
import 'tokens.dart';

/// THEME: SYSTEM (match the phone) | LIGHT | DARK.
class AppearancePrefs {
  final String theme;

  /// A little larger than the phone's own text size, on top of it.
  final bool largerText;

  /// Less movement, on top of the phone's own setting.
  final bool reduceMotion;

  const AppearancePrefs({this.theme = 'DARK', this.largerText = false, this.reduceMotion = false});

  AppearancePrefs copyWith({String? theme, bool? largerText, bool? reduceMotion}) =>
      AppearancePrefs(theme: theme ?? this.theme, largerText: largerText ?? this.largerText, reduceMotion: reduceMotion ?? this.reduceMotion);
}

/// How the app looks, kept on this phone. Dark is the default, as designed.
class AllyAppearance {
  AllyAppearance._();

  static final prefs = ValueNotifier<AppearancePrefs>(const AppearancePrefs());

  static const _kTheme = 'ally_theme', _kLarger = 'ally_larger_text', _kCalm = 'ally_reduce_motion';

  /// How much larger "larger text" makes everything.
  static const largerBy = 1.15;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      prefs.value = AppearancePrefs(
        theme: p.getString(_kTheme) ?? 'DARK',
        largerText: p.getBool(_kLarger) ?? false,
        reduceMotion: p.getBool(_kCalm) ?? false,
      );
    } catch (_) {
      // A convenience: the defaults are fine.
    }
  }

  static Future<void> set(AppearancePrefs next) async {
    prefs.value = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kTheme, next.theme);
      await p.setBool(_kLarger, next.largerText);
      await p.setBool(_kCalm, next.reduceMotion);
    } catch (_) {}
  }

  /// Dark or light for this screen, from the setting and, for SYSTEM, the phone.
  static Brightness brightnessOf(BuildContext context) => switch (prefs.value.theme) {
        'LIGHT' => Brightness.light,
        'SYSTEM' => MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.dark,
        _ => Brightness.dark,
      };

  /// The theme new-look screens wrap themselves in.
  static ThemeData themeOf(BuildContext context) => brightnessOf(context) == Brightness.light ? AllyTheme.light() : AllyTheme.dark();

  /// The colours outside any screen (the home-screen widget), from the saved
  /// choice and the phone's own setting.
  static AllyColors colorsNow() {
    final light = switch (prefs.value.theme) {
      'LIGHT' => true,
      'SYSTEM' => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light,
      _ => false,
    };
    return light ? AllyColors.light : AllyColors.dark;
  }

  static AllyColors colorsOf(BuildContext context) => brightnessOf(context) == Brightness.light ? AllyColors.light : AllyColors.dark;

  /// Applies larger text and reduced motion to everything under [child].
  static Widget apply(BuildContext context, Widget child) {
    final p = prefs.value;
    final mq = MediaQuery.of(context);
    final scaler = p.largerText ? _Times(mq.textScaler, largerBy) : mq.textScaler;
    return MediaQuery(
      data: mq.copyWith(textScaler: scaler, disableAnimations: mq.disableAnimations || p.reduceMotion),
      child: child,
    );
  }
}

/// The phone's text size, then a little more.
class _Times extends TextScaler {
  final TextScaler base;
  final double by;
  const _Times(this.base, this.by);

  @override
  double scale(double fontSize) => base.scale(fontSize) * by;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * by;

  @override
  bool operator ==(Object other) => other is _Times && other.base == base && other.by == by;

  @override
  int get hashCode => Object.hash(base, by);
}
