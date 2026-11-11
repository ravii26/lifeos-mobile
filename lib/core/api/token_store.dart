import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT securely across launches.
class TokenStore {
  static const _key = 'lifeos_jwt';
  final FlutterSecureStorage _storage;

  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  String? _cached;

  /// In-memory token for synchronous interceptor reads.
  String? get current => _cached;

  /// A phone can fail to decrypt what was stored (after a reinstall, a restore
  /// from backup or a changed signing key). That must never stop the app from
  /// opening: the stored data is useless anyway, so it is dropped and the person
  /// simply signs in again.
  Future<String?> read() async {
    try {
      _cached ??= await _storage.read(key: _key);
    } catch (_) {
      _cached = null;
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
    return _cached;
  }

  /// Kept in memory even if the phone cannot store it, so this session still works.
  Future<void> write(String token) async {
    _cached = token;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
  }

  Future<void> clear() async {
    _cached = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
