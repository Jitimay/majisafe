import 'package:dio/dio.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/services/api_service.dart';

class SimulateRepository {
  SimulateRepository({required ApiService apiService}) : _dio = apiService.client;

  final Dio _dio;

  /// Instantly credits coins by simulating a mobile-money payment.
  Future<Map<String, dynamic>> topup({
    required double amountBif,
    String method = 'simulate',
    String? note,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiConfig.simulateTopup,
      data: {
        'amount_bif': amountBif,
        'method': method,
        if (note != null) 'note': note,
      },
    );
    return res.data ?? {};
  }

  Future<List<Map<String, dynamic>>> history() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConfig.simulateHistory);
    final list = res.data?['payments'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
