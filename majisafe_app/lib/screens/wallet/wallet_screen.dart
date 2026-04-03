import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/config/theme.dart';
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.message, textAlign: TextAlign.center),
              ),
            );
          }
          if (state is! WalletLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<WalletBloc>().add(const WalletLoadRequested());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (state.offlineBanner != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Material(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.orange.shade900, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.offlineBanner!,
                                style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                CoinBalanceCard(coins: state.coins),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => context.push('/wallet/topup'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Regideso Coins'),
                ),
                const SizedBox(height: 28),
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (state.transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No transactions yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                else
                  ...state.transactions.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: TransactionTile(tx: t),
                      ),
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
