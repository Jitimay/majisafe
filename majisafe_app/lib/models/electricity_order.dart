import 'package:equatable/equatable.dart';

class ElectricityOrder extends Equatable {
  const ElectricityOrder({
    required this.id,
    required this.meterNumber,
    required this.coins,
    required this.kwh,
    required this.token,
    required this.status,
    this.createdAt,
  });

  factory ElectricityOrder.fromJson(Map<String, dynamic> json) {
    return ElectricityOrder(
      id: json['order_id'] as String? ?? json['id'] as String,
      meterNumber: json['meter_number'] as String,
      coins: _toDouble(json['coins_spent'] ?? json['coins']),
      kwh: _toDouble(json['kwh']),
      token: json['token'] as String,
      status: json['status'] as String? ?? 'confirmed',
      createdAt: json['created_at'] as String?,
    );
  }

  final String id;
  final String meterNumber;
  final double coins;
  final double kwh;
  final String token;
  final String status;
  final String? createdAt;

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  List<Object?> get props => [id, meterNumber, coins, kwh, token, status, createdAt];
}
