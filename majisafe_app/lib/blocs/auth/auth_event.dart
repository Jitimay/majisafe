import 'package:equatable/equatable.dart';

/// Auth-related user actions.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Restores session from secure storage + `/auth/me`.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Signs in with phone/password.
class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({required this.phone, required this.password});

  final String phone;
  final String password;

  @override
  List<Object?> get props => [phone, password];
}

/// Registers a new account.
class AuthRegisterSubmitted extends AuthEvent {
  const AuthRegisterSubmitted({
    required this.phone,
    required this.name,
    required this.password,
  });

  final String phone;
  final String name;
  final String password;

  @override
  List<Object?> get props => [phone, name, password];
}

/// Clears tokens and returns to login.
class AuthLogoutPressed extends AuthEvent {
  const AuthLogoutPressed();
}

/// Reloads `/auth/me` without showing global loading (e.g. after dispense).
class AuthSilentRefresh extends AuthEvent {
  const AuthSilentRefresh();
}

/// Clears [AuthAuthenticated.justRegistered] after the welcome UI was shown.
class AuthJustRegisteredAcknowledged extends AuthEvent {
  const AuthJustRegisteredAcknowledged();
}
