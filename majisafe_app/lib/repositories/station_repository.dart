import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/models/station.dart';
import 'package:majisafe_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Station list with optional 5-minute TTL cache for offline/near-offline UX.
class StationRepository {
  StationRepository({required ApiService apiService}) : _dio = apiService.client;

  final Dio _dio;

  static const _kStations = 'majisafe_stations_json';
  static const _kStationsTs = 'majisafe_stations_ts';
  static const _ttlMs = 5 * 60 * 1000;

  /// Fetches stations; on failure returns cache if younger than TTL.
  Future<List<Station>> listStations({bool forceRemote = false}) async {
    if (!forceRemote) {
      final cached = await _readCache();
      if (cached != null) return cached;
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiConfig.stations);
      final raw = res.data?['stations'] as List<dynamic>? ?? [];
      final list = raw.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
      await _writeCache(list);
      return list;
    } catch (_) {
      final cached = await _readCache(ignoreTtl: true);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Single station + recent activity (not cached).
  Future<Map<String, dynamic>> getStation(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConfig.stationDetail(id));
    return res.data ?? {};
  }

  Future<void> _writeCache(List<Station> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      list
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'location': s.location,
              'status': s.status,
              'tank_level': s.tankLevel,
              'last_seen': s.lastSeen,
              'sim_number': s.simNumber,
            },
          )
          .toList(),
    );
    await prefs.setString(_kStations, encoded);
    await prefs.setInt(_kStationsTs, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Station>?> _readCache({bool ignoreTtl = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStations);
    final ts = prefs.getInt(_kStationsTs);
    if (raw == null || ts == null) return null;
    if (!ignoreTtl && DateTime.now().millisecondsSinceEpoch - ts > _ttlMs) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// When the last station list was cached (for UI banner).
  Future<DateTime?> cacheTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kStationsTs);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }
}
