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

  Future<String?> read() async {
    _cached ??= await _storage.read(key: _key);
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}
