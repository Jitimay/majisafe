import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/widgets/coin_balance_card.dart';
import 'package:majisafe_app/widgets/transaction_tile.dart';

/// Balance + scrollable transaction list + top-up entry.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is WalletFailure) {
            return Center(child: Text(state.message));
          }
          if (state is! WalletLoaded) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<WalletBloc>().add(const WalletLoadRequested());
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.offlineBanner != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(state.offlineBanner!, style: TextStyle(color: Colors.orange.shade800)),
                  ),
                CoinBalanceCard(coins: state.coins),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.push('/wallet/topup'),
                  icon: const Icon(Icons.add),
                  label: const Text('Top Up'),
                ),
                const SizedBox(height: 24),
                Text('Recent', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (state.transactions.isEmpty)
                  const Text('No transactions yet.')
                else
                  Card(
                    child: Column(
                      children: state.transactions
                          .map((t) => TransactionTile(tx: t))
                          .toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
