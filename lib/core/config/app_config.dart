import 'dart:io';

import 'package:flutter/foundation.dart';

/// Central runtime configuration.
///
/// Override the API host at build/run time without touching code:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1
class AppConfig {
  AppConfig._();

  static const String _override = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const int _port = 3000;
  static const String _basePath = '/api/v1';

  /// Resolved base URL for the LifeOS backend.
  ///
  /// Defaults are dev-friendly:
  ///   - Android emulator  -> 10.0.2.2 (alias to host machine localhost)
  ///   - everything else   -> localhost
  /// For a physical phone, pass --dart-define=API_BASE_URL=http://<LAN-IP>:3000/api/v1
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    // final host = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : 'localhost';
    // final host = (!kIsWeb && Platform.isAndroid) ? '10.109.235.160' : 'localhost';
    // return 'http://$host:$_port$_basePath';
    return 'https://lifeos-api-2sjo.onrender.com/api/v1';
  }
}
