import 'package:dio/dio.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/models/user.dart';
import 'package:majisafe_app/services/api_service.dart';
import 'package:majisafe_app/services/auth_service.dart';

/// Remote auth: register, login, profile.
class AuthRepository {
  AuthRepository({
    required ApiService apiService,
    required AuthService authService,
  })  : _dio = apiService.client,
        _auth = authService;

  final Dio _dio;
  final AuthService _auth;

  /// Registers a new wallet user and persists tokens.
  Future<User> register({
    required String phone,
    required String name,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiConfig.authRegister,
      data: {'phone': phone, 'name': name, 'password': password},
    );
    final data = res.data!;
    final access = data['token'] as String;
    final refresh = data['refresh_token'] as String;
    await _auth.saveTokens(access: access, refresh: refresh);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Logs in and persists tokens.
  Future<User> login({required String phone, required String password}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiConfig.authLogin,
      data: {'phone': phone, 'password': password},
    );
    final data = res.data!;
    final access = data['token'] as String;
    final refresh = data['refresh_token'] as String;
    await _auth.saveTokens(access: access, refresh: refresh);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Fetches current profile (requires valid access token).
  Future<User> me() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConfig.authMe);
    final data = res.data!;
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Clears secure storage tokens.
  Future<void> logout() => _auth.clear();
}
