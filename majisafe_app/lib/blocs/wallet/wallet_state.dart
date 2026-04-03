import 'package:equatable/equatable.dart';
import 'package:majisafe_app/models/transaction.dart';

/// Wallet UI state.
abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {
  const WalletInitial();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

class WalletLoaded extends WalletState {
  const WalletLoaded({
    required this.coins,
    required this.transactions,
    this.cachedBalance,
    this.cachedAt,
    this.offlineBanner,
  });

  final double coins;
  final List<WalletTransaction> transactions;
  final double? cachedBalance;
  final DateTime? cachedAt;
  final String? offlineBanner;

  @override
  List<Object?> get props =>
      [coins, transactions, cachedBalance, cachedAt, offlineBanner];
}

class WalletHistoryLoaded extends WalletState {
  const WalletHistoryLoaded(this.transactions);

  final List<WalletTransaction> transactions;

  @override
  List<Object?> get props => [transactions];
}

class WalletFailure extends WalletState {
  const WalletFailure(this.message, {this.cachedCoins, this.cachedAt});

  final String message;
  final double? cachedCoins;
  final DateTime? cachedAt;

  @override
  List<Object?> get props => [message, cachedCoins, cachedAt];
}

class WalletTopupReady extends WalletState {
  const WalletTopupReady(this.payload);

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [payload];
}
