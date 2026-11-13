import 'dart:convert';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/token_store.dart';
import '../models/json.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiClient _api;
  final TokenStore _tokens;

  AuthRepository(this._api, this._tokens);

  Future<AppUser> register(
      {required String name,
      required String email,
      required String password}) async {
    final tz = await _deviceTimezone();
    final data = await _api.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      // Send the device's IANA zone so the backend computes "today"/streaks
      // /scores in the user's local time. Optional on the server.
      if (tz != null) 'timezone': tz,
    });
    return _persist(data);
  }

  /// Best-effort device IANA timezone (e.g. "Asia/Kolkata"); null if it can't
  /// be resolved (registration still succeeds without it).
  Future<String?> _deviceTimezone() async {
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      return tz.isEmpty ? null : tz;
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> login(
      {required String email, required String password}) async {
    final data = await _api
        .post('/auth/login', body: {'email': email, 'password': password});
    return _persist(data);
  }

  Future<AppUser> me() async {
    final data = await _api.get('/auth/me');
    final user = AppUser.fromJson(data as Json);
    await _remember(user);
    return user;
  }

  /// The account this phone last opened, so launch never waits on the server
  /// (a sleeping Render instance can take a minute). Null if never saved or
  /// unreadable; then the app checks with the server as before.
  Future<AppUser?> cachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cachedUserKey);
      if (raw == null) return null;
      final user = AppUser.fromJson(jsonDecode(raw) as Json);
      return user.id.isEmpty ? null : user;
    } catch (_) {
      return null;
    }
  }

  static const cachedUserKey = 'cached_user_v1';

  Future<void> _remember(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cachedUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<bool> hasSession() async => (await _tokens.read())?.isNotEmpty ?? false;

  Future<void> logout() => _tokens.clear();

  Future<AppUser> _persist(dynamic data) async {
    final map = data as Json;
    await _tokens.write(asString(map['token']));
    final user = AppUser.fromJson(map['user'] as Json);
    await _remember(user);
    return user;
  }
}
