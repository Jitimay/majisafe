import 'package:equatable/equatable.dart';

/// Ledger row shown in wallet / history.
class WalletTransaction extends Equatable {
  /// Creates a transaction model for UI lists.
  const WalletTransaction({
    required this.id,
    this.stationId,
    required this.type,
    required this.coins,
    this.volumeLitres,
    this.paymentMethod,
    required this.status,
    this.createdAt,
    this.note,
  });

  /// Parses API map from wallet or history endpoints.
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      stationId: json['station_id'] as String?,
      type: json['type'] as String? ?? 'unknown',
      coins: _toDouble(json['coins']),
      volumeLitres: json['volume_litres'] != null ? _toDouble(json['volume_litres']) : null,
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String?,
      note: json['note'] as String?,
    );
  }

  final String id;
  final String? stationId;
  final String type;
  final double coins;
  final double? volumeLitres;
  final String? paymentMethod;
  final String status;
  final String? createdAt;
  final String? note;

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  List<Object?> get props =>
      [id, stationId, type, coins, volumeLitres, paymentMethod, status, createdAt, note];
}
