import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/repositories/auth_repository.dart';
import 'package:majisafe_app/services/auth_service.dart';

/// Handles login, registration, session restore, and logout.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required AuthService authService,
  })  : _repo = authRepository,
        _authService = authService,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthRegisterSubmitted>(_onRegister);
    on<AuthLogoutPressed>(_onLogout);
    on<AuthSilentRefresh>(_onSilentRefresh);
    on<AuthJustRegisteredAcknowledged>(_onJustRegisteredAck);
  }

  final AuthRepository _repo;
  final AuthService _authService;

  Future<void> _onCheck(AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }
    try {
      final user = await _repo.me();
      emit(AuthAuthenticated(user));
    } catch (_) {
      await _repo.logout();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.login(phone: event.phone, password: event.password);
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      emit(AuthUnauthenticated(message: _msg(e)));
    } catch (e) {
      emit(AuthUnauthenticated(message: e.toString()));
    }
  }

  Future<void> _onRegister(AuthRegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.register(
        phone: event.phone,
        name: event.name,
        password: event.password,
        avatarBytes: event.avatarBytes == null ? null : Uint8List.fromList(event.avatarBytes!),
        avatarMime: event.avatarMime,
      );
      emit(AuthAuthenticated(user, justRegistered: true));
    } on DioException catch (e) {
      emit(AuthUnauthenticated(message: _msg(e)));
    } catch (e) {
      emit(AuthUnauthenticated(message: e.toString()));
    }
  }

  Future<void> _onLogout(AuthLogoutPressed event, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSilentRefresh(AuthSilentRefresh event, Emitter<AuthState> emit) async {
    final cur = state;
    if (cur is! AuthAuthenticated) return;
    try {
      final user = await _repo.me();
      emit(AuthAuthenticated(user, justRegistered: cur.justRegistered));
    } catch (_) {
      /* keep previous profile */
    }
  }

  void _onJustRegisteredAck(AuthJustRegisteredAcknowledged event, Emitter<AuthState> emit) {
    final cur = state;
    if (cur is AuthAuthenticated && cur.justRegistered) {
      emit(AuthAuthenticated(cur.user));
    }
  }

  static String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return e.message ?? 'Network error';
  }
}
