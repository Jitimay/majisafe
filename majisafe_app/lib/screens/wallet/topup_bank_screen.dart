import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Static bank transfer instructions after server top-up intent is recorded.
class TopUpBankScreen extends StatelessWidget {
  const TopUpBankScreen({super.key, required this.amountBif, required this.coins});

  final double amountBif;
  final double coins;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank transfer')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Transfer ${amountBif.toStringAsFixed(0)} BIF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Expected credit: ${coins.toStringAsFixed(coins == coins.roundToDouble() ? 0 : 1)} Regideso Coins',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            const Text('Bank: REGIDESO — Burundi (demo details)'),
            const Text('Account name: REGIDESO MajiSafe'),
            const Text('Reference: your phone number'),
            const SizedBox(height: 16),
            const Text(
              'After transfer, contact support with proof. An admin can credit your wallet manually.',
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
