import 'package:equatable/equatable.dart';

/// Authenticated REGIDESO wallet user profile.
class User extends Equatable {
  /// Creates a user from API JSON.
  const User({
    required this.id,
    required this.phone,
    this.name,
    required this.role,
    required this.coinBalance,
    this.createdAt,
  });

  /// Parses `/api/auth/me` or login payload `user` object.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      role: json['role'] as String? ?? 'user',
      coinBalance: _toDouble(json['coin_balance']),
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final String phone;
  final String? name;
  final String role;
  final double coinBalance;
  final String? createdAt;

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  User copyWith({
    int? id,
    String? phone,
    String? name,
    String? role,
    double? coinBalance,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      coinBalance: coinBalance ?? this.coinBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, phone, name, role, coinBalance, createdAt];
}
