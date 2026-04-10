import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/dispense/dispense_bloc.dart';
import 'package:majisafe_app/blocs/dispense/dispense_event.dart';
import 'package:majisafe_app/blocs/dispense/dispense_state.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/config/theme.dart';

class WaterResultScreen extends StatelessWidget {
  const WaterResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DispenseBloc>().state;
    final wallet = context.watch<WalletBloc>().state;
    final balance = wallet is WalletLoaded ? wallet.coins : null;

    final success = state is DispenseSuccess;
    final color = success ? AppTheme.primary : AppTheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Purchase'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          children: [
            // Icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(
                success ? Icons.water_drop_rounded : Icons.error_outline_rounded,
                color: color,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              success ? 'Water Dispensed!' : 'Dispense Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (state is DispenseSuccess)
              Text(
                '${state.actualLitres.toStringAsFixed(1)} litres delivered',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
              )
            else if (state is DispenseFailure)
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            const SizedBox(height: 32),

            // Details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: success
                      ? [AppTheme.primary, AppTheme.secondary]
                      : [AppTheme.error, const Color(0xFFB91C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (state is DispenseSuccess) ...[
                    _CardRow(label: 'Litres dispensed', value: '${state.actualLitres.toStringAsFixed(1)} L'),
                    _CardRow(label: 'Coins spent', value: '${state.coinsUsed.toStringAsFixed(1)}'),
                    if (balance != null) _CardRow(label: 'Remaining balance', value: '${balance.toStringAsFixed(1)} coins'),
                  ] else if (state is DispenseFailure) ...[
                    _CardRow(label: 'Status', value: state.refunded ? 'Refunded' : 'Failed'),
                    if (state.refunded) _CardRow(label: 'Coins', value: 'Returned to wallet'),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.read<DispenseBloc>().add(const DispenseReset());
                  context.go('/home');
                },
                child: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                context.read<DispenseBloc>().add(const DispenseReset());
                context.pushReplacement('/water/buy');
              },
              child: const Text('Buy Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
