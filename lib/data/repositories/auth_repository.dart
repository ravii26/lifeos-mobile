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
    final data = await _api.post('/auth/register',
        body: {'name': name, 'email': email, 'password': password});
    return _persist(data);
  }

  Future<AppUser> login(
      {required String email, required String password}) async {
    final data = await _api
        .post('/auth/login', body: {'email': email, 'password': password});
    return _persist(data);
  }

  Future<AppUser> me() async {
    final data = await _api.get('/auth/me');
    return AppUser.fromJson(data as Json);
  }

  Future<bool> hasSession() async => (await _tokens.read())?.isNotEmpty ?? false;

  Future<void> logout() => _tokens.clear();

  Future<AppUser> _persist(dynamic data) async {
    final map = data as Json;
    await _tokens.write(asString(map['token']));
    return AppUser.fromJson(map['user'] as Json);
  }
}
