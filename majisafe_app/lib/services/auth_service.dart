import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists access/refresh tokens and clears them on logout.
class AuthService {
  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccess = 'majisafe_access_token';
  static const _kRefresh = 'majisafe_refresh_token';

  /// Returns stored access token, or null.
  Future<String?> getAccessToken() => _storage.read(key: _kAccess);

  /// Returns stored refresh token, or null.
  Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);

  /// Writes both tokens after login/register/refresh.
  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  /// Updates only the access token after a silent refresh.
  Future<void> saveAccessToken(String access) async {
    await _storage.write(key: _kAccess, value: access);
  }

  /// Removes all auth material from secure storage.
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
