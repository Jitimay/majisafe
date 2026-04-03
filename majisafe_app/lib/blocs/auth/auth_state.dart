import 'package:equatable/equatable.dart';
import 'package:majisafe_app/models/user.dart';

/// Authentication UI state.
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial / splash while checking storage.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading during login/register/check.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Logged in with profile.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user, {this.justRegistered = false});

  final User user;

  /// True only right after a successful sign-up (for one-shot welcome UI).
  final bool justRegistered;

  @override
  List<Object?> get props => [user, justRegistered];
}

/// No valid session.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}
