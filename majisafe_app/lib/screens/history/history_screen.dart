import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/widgets/transaction_tile.dart';

/// Last 50 transactions.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletHistoryRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is WalletFailure) {
            return Center(child: Text(state.message));
          }
          if (state is! WalletHistoryLoaded) {
            return const SizedBox.shrink();
          }
          if (state.transactions.isEmpty) {
            return const Center(child: Text('No transactions yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<WalletBloc>().add(const WalletHistoryRequested());
            },
            child: ListView.builder(
              itemCount: state.transactions.length,
              itemBuilder: (context, i) {
                final t = state.transactions[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TransactionTile(
                    tx: t,
                    onTap: () => context.push('/history/detail', extra: t),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
