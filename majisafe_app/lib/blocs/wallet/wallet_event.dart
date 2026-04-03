import 'package:equatable/equatable.dart';

/// Wallet screen actions.
abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

/// Loads balance + embedded transactions from API (and updates cache).
class WalletLoadRequested extends WalletEvent {
  const WalletLoadRequested();
}

/// Loads last 50 transactions for history screen.
class WalletHistoryRequested extends WalletEvent {
  const WalletHistoryRequested();
}

/// Starts server-side pending top-up.
class WalletTopupSubmitted extends WalletEvent {
  const WalletTopupSubmitted({required this.amountBif, required this.method});

  final double amountBif;
  final String method;

  @override
  List<Object?> get props => [amountBif, method];
}

/// Clears transient UI state (e.g. after navigating away from top-up).
class WalletResetUi extends WalletEvent {
  const WalletResetUi();
}
