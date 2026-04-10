import 'package:dio/dio.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/models/electricity_order.dart';
import 'package:majisafe_app/services/api_service.dart';

class ElectricityRepository {
  ElectricityRepository({required ApiService apiService}) : _dio = apiService.client;

  final Dio _dio;

  Future<ElectricityOrder> buy({
    required String meterNumber,
    required double coins,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiConfig.electricityBuy,
      data: {'meter_number': meterNumber, 'coins': coins},
    );
    return ElectricityOrder.fromJson(res.data!);
  }

  Future<List<ElectricityOrder>> history() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConfig.electricityHistory);
    final orders = (res.data?['orders'] as List?) ?? [];
    return orders.map((e) => ElectricityOrder.fromJson(e as Map<String, dynamic>)).toList();
  }
}
