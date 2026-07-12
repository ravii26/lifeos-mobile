import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/api/api_client.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/core/api/token_store.dart';
import 'package:lifeos_mobile/data/models/user.dart';
import 'package:lifeos_mobile/data/repositories/auth_repository.dart';
import 'package:lifeos_mobile/features/auth/bloc/auth_bloc.dart';

const _user = AppUser(id: '1', email: 'a@b.com', name: 'Ada');

/// Stubs every network call so AuthBloc's own state-transition logic (the
/// thing actually worth locking in — auth is the one feature the mobile
/// audit found already uses Bloc correctly) can be tested without a real
/// ApiClient/TokenStore.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient(TokenStore()), TokenStore());

  bool sessionExists = false;
  AppUser? meResult;
  Object? meError;
  Object? loginError;
  Object? registerError;
  bool loggedOut = false;

  @override
  Future<bool> hasSession() async => sessionExists;

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    return meResult ?? _user;
  }

  @override
  Future<AppUser> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    return _user;
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (registerError != null) throw registerError!;
    return _user;
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

void main() {
  group('AuthBloc', () {
    late _FakeAuthRepository repo;

    setUp(() {
      repo = _FakeAuthRepository();
    });

    blocTest<AuthBloc, AuthState>(
      'emits unauthenticated on AuthStarted when no session exists',
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits authenticated with the user on AuthStarted when the session is valid',
      build: () {
        repo.sessionExists = true;
        repo.meResult = _user;
        return AuthBloc(repo);
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState(status: AuthStatus.authenticated, user: _user)],
    );

    blocTest<AuthBloc, AuthState>(
      'logs out and emits unauthenticated when the stored token is rejected (401)',
      build: () {
        repo.sessionExists = true;
        repo.meError = const ApiException('Unauthorized', statusCode: 401);
        return AuthBloc(repo);
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
      verify: (_) => expect(repo.loggedOut, isTrue),
    );

    blocTest<AuthBloc, AuthState>(
      'keeps the session and surfaces the error on a non-401 failure (e.g. cold start)',
      build: () {
        repo.sessionExists = true;
        repo.meError = const ApiException('Cannot reach the server.');
        return AuthBloc(repo);
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [
        const AuthState(status: AuthStatus.unknown, error: 'Cannot reach the server.'),
      ],
      verify: (_) => expect(repo.loggedOut, isFalse),
    );

    blocTest<AuthBloc, AuthState>(
      'login: authenticating then authenticated on success',
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthLoginRequested('a@b.com', 'password123')),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(status: AuthStatus.authenticated, user: _user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'login: authenticating then unauthenticated with the error message on failure',
      build: () {
        repo.loginError = const ApiException('Invalid credentials', statusCode: 401);
        return AuthBloc(repo);
      },
      act: (bloc) => bloc.add(const AuthLoginRequested('a@b.com', 'wrong')),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(status: AuthStatus.unauthenticated, error: 'Invalid credentials'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'register: authenticating then authenticated on success',
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthRegisterRequested('Ada', 'a@b.com', 'password123')),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(status: AuthStatus.authenticated, user: _user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'logout clears the token and resets to a fresh unauthenticated state',
      build: () => AuthBloc(repo),
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
      verify: (_) => expect(repo.loggedOut, isTrue),
    );
  });
}
