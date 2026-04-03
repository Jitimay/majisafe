import 'package:dio/dio.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/services/auth_service.dart';

/// Dio client with Bearer injection, 401 refresh-once, and typed base URL.
class ApiService {
  ApiService({required AuthService authService, Dio? dio})
      : _auth = authService,
        _dio = dio ?? Dio() {
    _dio.options.baseUrl = ApiConfig.baseUrl + ApiConfig.apiPrefix;
    // LAN / mobile networks can be slow to connect; cleartext HTTP on Android may also delay before failing.
    _dio.options.connectTimeout = const Duration(seconds: 45);
    _dio.options.sendTimeout = const Duration(seconds: 45);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (err, handler) async {
          final path = err.requestOptions.path;
          if (path.contains('auth/refresh')) {
            await _auth.clear();
            return handler.next(err);
          }
          if (err.response?.statusCode != 401) {
            return handler.next(err);
          }
          final refresh = await _auth.getRefreshToken();
          if (refresh == null || refresh.isEmpty || err.requestOptions.extra['retried'] == true) {
            await _auth.clear();
            return handler.next(err);
          }
          try {
            final res = await _dio.post<Map<String, dynamic>>(
              ApiConfig.authRefresh,
              data: {'refresh_token': refresh},
              options: Options(extra: {'retried': true}),
            );
            final data = res.data;
            final access = data?['token'] as String?;
            final newRefresh = data?['refresh_token'] as String?;
            if (access == null) {
              await _auth.clear();
              return handler.next(err);
            }
            if (newRefresh != null) {
              await _auth.saveTokens(access: access, refresh: newRefresh);
            } else {
              await _auth.saveAccessToken(access);
            }
            final req = err.requestOptions;
            req.headers['Authorization'] = 'Bearer $access';
            req.extra['retried'] = true;
            final clone = await _dio.fetch(req);
            return handler.resolve(clone);
          } catch (_) {
            await _auth.clear();
            return handler.next(err);
          }
        },
      ),
    );
  }

  final AuthService _auth;
  final Dio _dio;

  /// Underlying Dio for repositories.
  Dio get client => _dio;

  /// Clears tokens (e.g. after logout).
  Future<void> logoutStorage() => _auth.clear();
}
