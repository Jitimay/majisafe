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
    this.hasAvatar = false,
  });

  /// Parses `/api/auth/me` or login payload `user` object.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _toInt(json['id']),
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString(),
      role: json['role']?.toString() ?? 'user',
      coinBalance: _toDouble(json['coin_balance']),
      createdAt: json['created_at']?.toString(),
      hasAvatar: _toBool(json['has_avatar']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  final int id;
  final String phone;
  final String? name;
  final String role;
  final double coinBalance;
  final String? createdAt;
  final bool hasAvatar;

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
    bool? hasAvatar,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      coinBalance: coinBalance ?? this.coinBalance,
      createdAt: createdAt ?? this.createdAt,
      hasAvatar: hasAvatar ?? this.hasAvatar,
    );
  }

  @override
  List<Object?> get props => [id, phone, name, role, coinBalance, createdAt, hasAvatar];
}
