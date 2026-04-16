import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/repositories/simulate_repository.dart';

/// Sandbox payment screen — simulates mobile-money top-up instantly.
/// Shown in the wallet top-up flow as a "Simulate Payment" option.
class SimulateTopupScreen extends StatefulWidget {
  const SimulateTopupScreen({super.key});

  @override
  State<SimulateTopupScreen> createState() => _SimulateTopupScreenState();
}

class _SimulateTopupScreenState extends State<SimulateTopupScreen> {
  double _amountBif = 500;
  String _method = 'lumicash';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  static const _methods = ['lumicash', 'ecocash', 'bank', 'cash'];
  static const _presets = [100.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];

  double get _coins => _amountBif / 10; // COIN_PRICE_BIF = 10

  Future<void> _pay() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final repo = context.read<SimulateRepository>();
      final data = await repo.topup(
        amountBif: _amountBif,
        method: _method,
        note: 'Simulated $_method payment',
      );
      if (!mounted) return;
      setState(() {
        _result = data;
        _loading = false;
      });
      // Refresh wallet balance
      context.read<WalletBloc>().add(const WalletLoadRequested());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulate Payment'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_rounded, color: Colors.orange, size: 14),
                SizedBox(width: 4),
                Text('SANDBOX', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
      body: _result != null ? _SuccessView(result: _result!, onDone: () => context.go('/wallet')) : _FormView(
        amountBif: _amountBif,
        method: _method,
        coins: _coins,
        loading: _loading,
        error: _error,
        presets: _presets,
        methods: _methods,
        onAmountChanged: (v) => setState(() => _amountBif = v),
        onMethodChanged: (v) => setState(() => _method = v),
        onPay: _pay,
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.amountBif,
    required this.method,
    required this.coins,
    required this.loading,
    required this.error,
    required this.presets,
    required this.methods,
    required this.onAmountChanged,
    required this.onMethodChanged,
    required this.onPay,
  });

  final double amountBif;
  final String method;
  final double coins;
  final bool loading;
  final String? error;
  final List<double> presets;
  final List<String> methods;
  final ValueChanged<double> onAmountChanged;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is a sandbox simulator. No real money is charged. '
                    'Use this to test the app before connecting a real payment gateway.',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Amount (BIF)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${amountBif.toInt()} BIF = ${coins.toStringAsFixed(1)} coins',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: amountBif,
            min: 100,
            max: 10000,
            divisions: 99,
            activeColor: AppTheme.primary,
            label: '${amountBif.toInt()} BIF',
            onChanged: loading ? null : onAmountChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: presets.map((v) {
              final sel = amountBif == v;
              return ChoiceChip(
                label: Text('${v.toInt()}'),
                selected: sel,
                selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                onSelected: loading ? null : (_) => onAmountChanged(v),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Payment method
          Text('Payment Method', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...methods.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: method == m
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: method == m ? AppTheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                  width: method == m ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: loading ? null : () => onMethodChanged(m),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(_methodIcon(m), color: method == m ? AppTheme.primary : AppTheme.textMuted, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        _methodLabel(m),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: method == m ? AppTheme.primary : null,
                        ),
                      ),
                      const Spacer(),
                      if (method == m) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          )),
          const SizedBox(height: 28),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _Row(label: 'Amount', value: '${amountBif.toInt()} BIF'),
                _Row(label: 'Method', value: _methodLabel(method)),
                _Row(label: 'Coins you get', value: '${coins.toStringAsFixed(1)} coins'),
                _Row(label: 'Rate', value: '10 BIF = 1 coin'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(error!, style: TextStyle(color: AppTheme.error)),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payments_rounded),
              label: Text(loading ? 'Processing...' : 'Simulate ${amountBif.toInt()} BIF Payment'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: loading ? null : onPay,
            ),
          ),
        ],
      ),
    );
  }

  IconData _methodIcon(String m) {
    switch (m) {
      case 'lumicash': return Icons.phone_android_rounded;
      case 'ecocash': return Icons.smartphone_rounded;
      case 'bank': return Icons.account_balance_rounded;
      case 'cash': return Icons.money_rounded;
      default: return Icons.payment_rounded;
    }
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'lumicash': return 'Lumicash (Mobile Money)';
      case 'ecocash': return 'EcoCash';
      case 'bank': return 'Bank Transfer';
      case 'cash': return 'Cash';
      default: return m;
    }
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result, required this.onDone});
  final Map<String, dynamic> result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final coins = (result['coins_credited'] as num?)?.toDouble() ?? 0;
    final ref = result['payment_ref'] as String? ?? '—';
    final amount = (result['amount_bif'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'Payment Simulated!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${coins.toStringAsFixed(1)} coins added to your wallet',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _CardRow(label: 'Reference', value: ref),
                _CardRow(label: 'Amount paid', value: '$amount BIF'),
                _CardRow(label: 'Coins credited', value: '${coins.toStringAsFixed(1)}'),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Go to Wallet'),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
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
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
