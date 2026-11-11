import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/api/api_client.dart';
import 'package:lifeos_mobile/core/api/token_store.dart';
import 'package:lifeos_mobile/data/models/user.dart';
import 'package:lifeos_mobile/data/repositories/auth_repository.dart';
import 'package:lifeos_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A phone whose secure storage cannot decrypt what it holds.
class _BrokenStorage extends FlutterSecureStorage {
  bool cleared = false;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      throw PlatformException(code: 'Exception', message: 'BadPaddingException');

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      throw PlatformException(code: 'Exception');

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      cleared = true;
}

class _Repo extends AuthRepository {
  _Repo() : super(ApiClient(TokenStore()), TokenStore());
  Object? sessionError;
  Object? meError;

  @override
  Future<bool> hasSession() async {
    if (sessionError != null) throw sessionError!;
    return true;
  }

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    return const AppUser(id: '1', email: 'a@b.c', name: 'A');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a phone that cannot read its saved sign-in', () {
    test('reading does not throw, and the bad data is dropped', () async {
      final storage = _BrokenStorage();
      final store = TokenStore(storage);
      expect(await store.read(), isNull);
      expect(storage.cleared, isTrue);
    });

    test('signing in still works for this session', () async {
      final store = TokenStore(_BrokenStorage());
      await store.write('token');
      expect(store.current, 'token');
    });
  });

  group('starting up never ends in an endless spinner', () {
    Future<AuthState> settle(AuthBloc bloc) async {
      bloc.add(const AuthStarted());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return bloc.state;
    }

    test('an unexpected error shows a message with a way to retry', () async {
      final repo = _Repo()..meError = const FormatException('bad reply');
      final bloc = AuthBloc(repo);
      final s = await settle(bloc);
      expect(s.status, AuthStatus.unknown);
      expect(s.error, contains('bad reply'));
      await bloc.close();
    });

    test('a failure checking the session is handled too', () async {
      final repo = _Repo()..sessionError = StateError('storage');
      final bloc = AuthBloc(repo);
      final s = await settle(bloc);
      expect(s.error, isNotNull);
      await bloc.close();
    });

    test('Try again clears the old error and can succeed', () async {
      final repo = _Repo()..meError = const FormatException('bad reply');
      final bloc = AuthBloc(repo);
      await settle(bloc);
      repo.meError = null;
      final s = await settle(bloc);
      expect(s.status, AuthStatus.authenticated);
      expect(s.error, isNull);
      await bloc.close();
    });
  });
}
