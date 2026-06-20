part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

/// Fired at startup — restores a session if a token exists.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  const AuthRegisterRequested(this.name, this.email, this.password);
  @override
  List<Object?> get props => [name, email, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
