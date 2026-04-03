import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/widgets/transaction_tile.dart';

/// Last 50 transactions.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<WalletBloc>().state;
    if (s is WalletHistoryLoaded) {
      _busy = false;
    } else {
      context.read<WalletBloc>().add(const WalletHistoryRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: BlocConsumer<WalletBloc, WalletState>(
        listenWhen: (p, c) => c is WalletHistoryLoaded || c is WalletFailure,
        listener: (_, __) {
          if (mounted) setState(() => _busy = false);
        },
        builder: (context, state) {
          if (_busy && state is! WalletHistoryLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is WalletFailure && state.message.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.message, textAlign: TextAlign.center),
              ),
            );
          }
          if (state is! WalletHistoryLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<WalletBloc>().add(const WalletHistoryRequested());
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: state.transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = state.transactions[i];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
                    ),
                  ),
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
