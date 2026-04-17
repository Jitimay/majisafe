import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/repositories/wallet_repository.dart';

/// Loads balance/history and handles top-up API calls.
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({required WalletRepository repository})
      : _repo = repository,
        super(const WalletInitial()) {
    on<WalletLoadRequested>(_onLoad);
    on<WalletHistoryRequested>(_onHistory);
    on<WalletTopupSubmitted>(_onTopup);
    on<WalletResetUi>((_, emit) => emit(const WalletInitial()));
  }

  final WalletRepository _repo;

  Future<void> _onLoad(WalletLoadRequested event, Emitter<WalletState> emit) async {
    emit(const WalletLoading());
    final conn = await Connectivity().checkConnectivity();
    final offline = conn.contains(ConnectivityResult.none);
    final cached = await _repo.cachedBalance();
    if (offline) {
      if (cached.coins != null) {
        emit(
          WalletLoaded(
            coins: cached.coins!,
            transactions: const [],
            cachedBalance: cached.coins,
            cachedAt: cached.at,
            offlineBanner: 'No connection — showing last known balance.',
          ),
        );
      } else {
        emit(
          WalletFailure(
            'No connection',
            cachedCoins: cached.coins,
            cachedAt: cached.at,
          ),
        );
      }
      return;
    }
    try {
      final r = await _repo.fetchBalance();
      emit(WalletLoaded(coins: r.coins, transactions: r.transactions));
    } on DioException catch (e) {
      if (cached.coins != null) {
        emit(
          WalletLoaded(
            coins: cached.coins!,
            transactions: const [],
            cachedBalance: cached.coins,
            cachedAt: cached.at,
            offlineBanner: 'Could not refresh — last updated ${_fmt(cached.at)}.',
          ),
        );
      } else {
        emit(WalletFailure(e.message ?? 'Load failed'));
      }
    } catch (e) {
      emit(WalletFailure(e.toString()));
    }
  }

  Future<void> _onHistory(WalletHistoryRequested event, Emitter<WalletState> emit) async {
    emit(const WalletHistoryLoading());
    try {
      final list = await _repo.fetchHistory().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out. Check your connection.'),
      );
      emit(WalletHistoryLoaded(list));
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] is String)
          ? data['message'] as String
          : e.message ?? 'Failed to load history';
      emit(WalletFailure(msg));
    } catch (e) {
      emit(WalletFailure(e.toString()));
    }
  }

  Future<void> _onTopup(WalletTopupSubmitted event, Emitter<WalletState> emit) async {
    emit(const WalletLoading());
    try {
      final payload = await _repo.topup(amountBif: event.amountBif, method: event.method);
      emit(WalletTopupReady(payload));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        emit(WalletFailure(data['message'] as String));
      } else {
        emit(WalletFailure(e.message ?? 'Top-up failed'));
      }
    } catch (e) {
      emit(WalletFailure(e.toString()));
    }
  }

  static String _fmt(DateTime? t) {
    if (t == null) return 'unknown';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 2) return 'just now';
    return '${diff.inMinutes} min ago';
  }
}
