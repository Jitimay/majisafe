import 'dart:convert';
import 'dart:typed_data';

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

  /// Same format for register and login so `+257…` matches `257…`.
  static String normalizePhone(String phone) {
    var s = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (s.startsWith('+')) {
      s = s.substring(1);
    }
    return s;
  }

  static Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw FormatException('Expected JSON object, got ${raw.runtimeType}');
  }

  static String? _stringField(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  /// Normalizes Dio JSON body to a single map (handles `Map<dynamic, dynamic>` from parsers).
  static Map<String, dynamic> _responseMap(Response<dynamic> res) {
    final raw = res.data;
    if (raw == null) {
      throw FormatException('Empty response (HTTP ${res.statusCode})');
    }
    if (raw is! Map) {
      throw FormatException('Expected JSON object, got ${raw.runtimeType}');
    }
    return Map<String, dynamic>.from(raw);
  }

  /// Registers a new wallet user and persists tokens.
  Future<User> register({
    required String phone,
    required String name,
    required String password,
    Uint8List? avatarBytes,
    String? avatarMime,
  }) async {
    final payload = <String, dynamic>{
      'phone': normalizePhone(phone),
      'name': name,
      'password': password,
    };
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      payload['avatar_base64'] = base64Encode(avatarBytes);
      payload['avatar_mime'] = avatarMime ?? 'image/jpeg';
    }
    final res = await _dio.post<dynamic>(
      ApiConfig.authRegister,
      data: payload,
    );
    final body = _responseMap(res);
    final user = User.fromJson(_asJsonMap(body['user']));
    final access = _stringField(body['token']);
    final refresh = _stringField(body['refresh_token']);
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      throw FormatException('Missing token in register response');
    }
    await _auth.saveTokens(access: access, refresh: refresh);
    return user;
  }

  /// Logs in and persists tokens.
  Future<User> login({required String phone, required String password}) async {
    final res = await _dio.post<dynamic>(
      ApiConfig.authLogin,
      data: {
        'phone': normalizePhone(phone),
        'password': password,
      },
    );
    final data = _responseMap(res);
    final user = User.fromJson(_asJsonMap(data['user']));
    final access = _stringField(data['token']);
    final refresh = _stringField(data['refresh_token']);
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      throw FormatException('Missing token in login response');
    }
    await _auth.saveTokens(access: access, refresh: refresh);
    return user;
  }

  /// Fetches current profile (requires valid access token).
  Future<User> me() async {
    final res = await _dio.get<dynamic>(ApiConfig.authMe);
    final data = _responseMap(res);
    return User.fromJson(_asJsonMap(data['user']));
  }

  /// Clears secure storage tokens.
  Future<void> logout() => _auth.clear();
}
