import 'package:dio/dio.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/services/api_service.dart';

/// Dispense request + status polling.
class DispenseRepository {
  DispenseRepository({required ApiService apiService}) : _dio = apiService.client;

  final Dio _dio;

  /// POST /dispense/request → { tx_id, ... }.
  Future<Map<String, dynamic>> requestDispense({
    required String stationId,
    required double litres,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiConfig.dispenseRequest,
      data: {'station_id': stationId, 'litres': litres},
    );
    return res.data ?? {};
  }

  /// GET /dispense/status/:txId for polling.
  Future<Map<String, dynamic>> dispenseStatus(String txId) async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConfig.dispenseStatus(txId));
    return res.data ?? {};
  }
}
