import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc(this._repo) : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onStarted(AuthStarted e, Emitter<AuthState> emit) async {
    if (!await _repo.hasSession()) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }
    try {
      final user = await _repo.me();
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _repo.logout();
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      } else {
        // Network/server issue (e.g. Render cold start) — keep the token and
        // let the user retry instead of being kicked to login.
        emit(state.copyWith(status: AuthStatus.unknown, error: e.message));
      }
    }
  }

  Future<void> _onLogin(
      AuthLoginRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      final user = await _repo.login(email: e.email, password: e.password);
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } on ApiException catch (err) {
      emit(state.copyWith(
          status: AuthStatus.unauthenticated, error: err.message));
    }
  }

  Future<void> _onRegister(
      AuthRegisterRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      final user = await _repo.register(
          name: e.name, email: e.email, password: e.password);
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } on ApiException catch (err) {
      emit(state.copyWith(
          status: AuthStatus.unauthenticated, error: err.message));
    }
  }

  Future<void> _onLogout(
      AuthLogoutRequested e, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
