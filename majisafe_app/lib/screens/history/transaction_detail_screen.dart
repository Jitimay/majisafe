import 'package:flutter/material.dart';
import 'package:majisafe_app/models/transaction.dart';

/// Single transaction detail view.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(title: const Text('ID'), subtitle: Text(tx.id)),
          ListTile(title: const Text('Type'), subtitle: Text(tx.type)),
          ListTile(title: const Text('Status'), subtitle: Text(tx.status)),
          ListTile(
            title: const Text('Coins'),
            subtitle: Text(tx.coins.toStringAsFixed(2)),
          ),
          if (tx.volumeLitres != null)
            ListTile(
              title: const Text('Volume (L)'),
              subtitle: Text(tx.volumeLitres!.toStringAsFixed(2)),
            ),
          if (tx.stationId != null)
            ListTile(title: const Text('Station'), subtitle: Text(tx.stationId!)),
          if (tx.paymentMethod != null)
            ListTile(title: const Text('Payment'), subtitle: Text(tx.paymentMethod!)),
          if (tx.createdAt != null)
            ListTile(title: const Text('When'), subtitle: Text(tx.createdAt!)),
          if (tx.note != null) ListTile(title: const Text('Note'), subtitle: Text(tx.note!)),
        ],
      ),
    );
  }
}
