import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists access/refresh tokens. Uses secure storage first; falls back to
/// [SharedPreferences] if the KeyStore path fails (common on some Android builds).
class AuthService {
  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ??
            FlutterSecureStorage(
              aOptions: const AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'majisafe_access_token';
  static const _kRefresh = 'majisafe_refresh_token';
  /// Fallback keys if [FlutterSecureStorage] throws (device still works; less secure).
  static const _kAccessFallback = 'majisafe_access_token_fb';
  static const _kRefreshFallback = 'majisafe_refresh_token_fb';

  /// Returns stored access token, or null.
  Future<String?> getAccessToken() async {
    try {
      final v = await _storage.read(key: _kAccess);
      if (v != null && v.isNotEmpty) return v;
    } catch (e, st) {
      debugPrint('AuthService.getAccessToken secure read: $e\n$st');
    }
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAccessFallback);
  }

  /// Returns stored refresh token, or null.
  Future<String?> getRefreshToken() async {
    try {
      final v = await _storage.read(key: _kRefresh);
      if (v != null && v.isNotEmpty) return v;
    } catch (e, st) {
      debugPrint('AuthService.getRefreshToken secure read: $e\n$st');
    }
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRefreshFallback);
  }

  /// Writes both tokens after login/register/refresh.
  Future<void> saveTokens({required String access, required String refresh}) async {
    try {
      await _storage.write(key: _kAccess, value: access);
      await _storage.write(key: _kRefresh, value: refresh);
      final p = await SharedPreferences.getInstance();
      await p.remove(_kAccessFallback);
      await p.remove(_kRefreshFallback);
      return;
    } catch (e, st) {
      debugPrint('AuthService.saveTokens secure write failed, using fallback: $e\n$st');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccessFallback, access);
    await p.setString(_kRefreshFallback, refresh);
  }

  /// Updates only the access token after a silent refresh.
  Future<void> saveAccessToken(String access) async {
    try {
      await _storage.write(key: _kAccess, value: access);
      final p = await SharedPreferences.getInstance();
      await p.setString(_kAccessFallback, access);
      return;
    } catch (e, st) {
      debugPrint('AuthService.saveAccessToken: $e\n$st');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccessFallback, access);
  }

  /// Removes all auth material from storage.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccessFallback);
    await p.remove(_kRefreshFallback);
  }
}
