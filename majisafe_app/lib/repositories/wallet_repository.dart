import 'package:dio/dio.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/models/transaction.dart';
import 'package:majisafe_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wallet balance, history, and top-up initiation.
class WalletRepository {
  WalletRepository({required ApiService apiService}) : _dio = apiService.client;

  final Dio _dio;

  static const _kBalance = 'majisafe_cached_balance';
  static const _kBalanceTs = 'majisafe_cached_balance_ts';

  /// GET balance + embedded recent transactions; caches coins in SharedPreferences.
  Future<({double coins, List<WalletTransaction> transactions})> fetchBalance() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConfig.walletBalance);
    final data = res.data!;
    final coins = _toDouble(data['coins']);
    final raw = data['transactions'] as List<dynamic>? ?? [];
    final list = raw.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBalance, coins);
    await prefs.setInt(_kBalanceTs, DateTime.now().millisecondsSinceEpoch);
    return (coins: coins, transactions: list);
  }

  /// Last 50 transactions.
  Future<List<WalletTransaction>> fetchHistory() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConfig.walletHistory);
    final raw = res.data?['transactions'] as List<dynamic>? ?? [];
    return raw.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Starts a top-up (creates pending top-up on server).
  Future<Map<String, dynamic>> topup({required double amountBif, required String method}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiConfig.walletTopup,
      data: {'amount_bif': amountBif, 'method': method},
    );
    return res.data ?? {};
  }

  /// Cached balance when offline (may be stale).
  Future<({double? coins, DateTime? at})> cachedBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getDouble(_kBalance);
    final ts = prefs.getInt(_kBalanceTs);
    if (c == null || ts == null) return (coins: null, at: null);
    return (coins: c, at: DateTime.fromMillisecondsSinceEpoch(ts));
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
