import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/models/transaction.dart';

/// One row in wallet / history lists.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, this.onTap});

  final WalletTransaction tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(tx.type);
    final title = _titleFor(tx);
    final subtitle = tx.createdAt != null ? _formatDate(tx.createdAt!) : '';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: AppTheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${tx.coins >= 0 ? '+' : ''}${tx.coins.toStringAsFixed(tx.coins == tx.coins.roundToDouble() ? 0 : 1)} coins',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          _StatusChip(status: tx.status),
        ],
      ),
      onTap: onTap,
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'dispense':
        return Icons.water_drop_outlined;
      case 'refund':
        return Icons.undo;
      case 'topup':
        return Icons.savings_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  String _titleFor(WalletTransaction tx) {
    switch (tx.type) {
      case 'dispense':
        return 'Dispense${tx.stationId != null ? ' · ${tx.stationId}' : ''}';
      case 'refund':
        return 'Refund';
      case 'topup':
        return 'Top-up';
      default:
        return tx.type;
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      return DateFormat.yMMMd().add_jm().format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color c = Colors.grey;
    if (status == 'confirmed') c = AppTheme.primary;
    if (status == 'pending') c = Colors.orange;
    if (status == 'failed' || status == 'refunded') c = AppTheme.error;
    return Text(
      status,
      style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500),
    );
  }
}
