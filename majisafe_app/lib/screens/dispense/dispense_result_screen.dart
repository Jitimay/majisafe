import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/blocs/dispense/dispense_bloc.dart';
import 'package:majisafe_app/blocs/dispense/dispense_event.dart';
import 'package:majisafe_app/blocs/dispense/dispense_state.dart';
import 'package:majisafe_app/config/theme.dart';

/// Success or failure summary after a dispense attempt.
class DispenseResultScreen extends StatelessWidget {
  const DispenseResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DispenseBloc>().state;
    final auth = context.watch<AuthBloc>().state;
    final wallet = context.watch<WalletBloc>().state;
    double? balance;
    if (wallet is WalletLoaded) {
      balance = wallet.coins;
    } else if (auth is AuthAuthenticated) {
      balance = auth.user.coinBalance;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (d is DispenseSuccess) ...[
              const Icon(Icons.water_drop, size: 80, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                '${d.actualLitres.toStringAsFixed(1)} litres dispensed',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('${d.coinsUsed.toStringAsFixed(1)} coins used'),
              if (balance != null) Text('New balance: ${balance.toStringAsFixed(1)}'),
            ] else if (d is DispenseFailure) ...[
              Icon(Icons.error_outline, size: 80, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(d.message, textAlign: TextAlign.center),
              if (d.refunded) const Text('Coins were refunded to your wallet.'),
            ] else
              const Text('No result.'),
            const Spacer(),
            FilledButton(
              onPressed: () {
                context.read<DispenseBloc>().add(const DispenseReset());
                context.go('/home');
              },
              child: const Text('Done'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                context.read<DispenseBloc>().add(const DispenseReset());
                context.go('/dispense/stations');
              },
              child: const Text('Dispense again'),
            ),
          ],
        ),
      ),
    );
  }
}
