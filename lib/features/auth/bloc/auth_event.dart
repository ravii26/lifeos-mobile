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

/// "Get started" on the welcome screen.
class AuthGuestRequested extends AuthEvent {
  const AuthGuestRequested();
}

/// The account changed in place (a guest account was saved).
class AuthUserUpdated extends AuthEvent {
  final AppUser user;
  const AuthUserUpdated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
