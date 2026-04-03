/// API base URL and path constants (override with --dart-define=API_BASE_URL=...).
class ApiConfig {
  ApiConfig._();

  /// Android emulator: use `http://10.0.2.2:3000`. iOS simulator: `http://127.0.0.1:3000`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static const String apiPrefix = '/api';

  static String url(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$apiPrefix$p';
  }

  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authMe = '/auth/me';
  static const String walletBalance = '/wallet/balance';
  static const String walletTopup = '/wallet/topup';
  static const String walletHistory = '/wallet/history';
  static const String dispenseRequest = '/dispense/request';
  static String dispenseStatus(String txId) => '/dispense/status/$txId';
  static const String stations = '/stations';
  static String stationDetail(String id) => '/stations/$id';

  /// REGIDESO merchant number shown in USSD instructions (align with backend admin phone in production).
  static const String regidesoMerchantPhone = '25761000000';
}
