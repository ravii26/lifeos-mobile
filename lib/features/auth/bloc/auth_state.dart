part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final AppUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AppUser? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );

  @override
  List<Object?> get props => [status, user, error];
}
