import 'package:equatable/equatable.dart';

/// Water dispensing station metadata from `/api/stations`.
class Station extends Equatable {
  /// Creates a station for lists and detail screens.
  const Station({
    required this.id,
    this.name,
    this.location,
    required this.status,
    this.tankLevel,
    this.lastSeen,
    this.simNumber,
    this.distanceKm,
  });

  /// Parses API JSON; [distanceKm] is filled client-side when GPS is available.
  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String?,
      location: json['location'] as String?,
      status: json['status'] as String? ?? 'offline',
      tankLevel: json['tank_level'] != null ? _toDouble(json['tank_level']) : null,
      lastSeen: json['last_seen'] as String?,
      simNumber: json['sim_number'] as String?,
    );
  }

  final String id;
  final String? name;
  final String? location;
  final String status;
  final double? tankLevel;
  final String? lastSeen;
  final String? simNumber;
  final double? distanceKm;

  Station copyWith({double? distanceKm}) {
    return Station(
      id: id,
      name: name,
      location: location,
      status: status,
      tankLevel: tankLevel,
      lastSeen: lastSeen,
      simNumber: simNumber,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  List<Object?> get props =>
      [id, name, location, status, tankLevel, lastSeen, simNumber, distanceKm];
}
