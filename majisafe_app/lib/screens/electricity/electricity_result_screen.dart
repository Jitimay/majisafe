import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/electricity/electricity_bloc.dart';
import 'package:majisafe_app/blocs/electricity/electricity_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/models/electricity_order.dart';

class ElectricityResultScreen extends StatefulWidget {
  const ElectricityResultScreen({super.key, required this.order});
  final ElectricityOrder order;

  @override
  State<ElectricityResultScreen> createState() => _ElectricityResultScreenState();
}

class _ElectricityResultScreenState extends State<ElectricityResultScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh wallet balance after purchase
    context.read<WalletBloc>().add(const WalletLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Complete'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          children: [
            // Success icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Electricity Purchased!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the token below on your meter',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 32),
            // Token card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('TOKEN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text(
                    order.token,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: order.token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Token copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                    label: const Text('Copy token', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _Row(label: 'Meter', value: order.meterNumber),
                  _Row(label: 'Energy', value: '${order.kwh.toStringAsFixed(0)} kWh'),
                  _Row(label: 'Coins spent', value: order.coins.toStringAsFixed(0)),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.read<ElectricityBloc>().add(const ElectricityReset());
                  context.go('/home');
                },
                child: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                context.read<ElectricityBloc>().add(const ElectricityReset());
                context.pushReplacement('/electricity/buy');
              },
              child: const Text('Buy Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
