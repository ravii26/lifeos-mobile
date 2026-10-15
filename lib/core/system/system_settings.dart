import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android battery settings, through the small "ally/system" channel in
/// MainActivity.kt. Samsung's battery saver holds reminders back unless Ally
/// is left out of it ("Unrestricted").
class SystemSettings {
  static const _channel = MethodChannel('ally/system');

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isBatteryUnrestricted() async {
    if (!_android) return true;
    try {
      return await _channel.invokeMethod<bool>('isBatteryUnrestricted') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows Android's "let Ally always run in the background?" dialog, or the
  /// app's settings page where Battery → Unrestricted can be chosen.
  static Future<void> requestBatteryUnrestricted() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<bool>('requestBatteryUnrestricted');
    } catch (_) {}
  }

  static Future<void> openAppSettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<bool>('openAppSettings');
    } catch (_) {}
  }
}
