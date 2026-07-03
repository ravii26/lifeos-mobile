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

  /// Resolved base URL for the LifeOS backend.
  ///
  /// For a physical phone or local dev, pass
  /// `--dart-define=API_BASE_URL=http://LAN-IP:3000/api/v1`
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    return 'https://lifeos-api-2sjo.onrender.com/api/v1';
  }
}
