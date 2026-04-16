import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/widgets/error_snackbar.dart';

/// Preset BIF amounts, coin preview, and payment method selection.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  double _amount = 1000;
  String _method = 'lumicash';
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletResetUi());
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  double get _coinPrice => 10; // mirror server default; server returns coin_price in response

  @override
  Widget build(BuildContext context) {
    final coins = _amount / _coinPrice;
    return Scaffold(
      appBar: AppBar(title: const Text('Top Up')),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletFailure) {
            showErrorSnackBar(context, state.message);
          }
          if (state is WalletTopupReady) {
            final price = (state.payload['coin_price_bif'] as num?)?.toDouble() ?? _coinPrice;
            final amt = (state.payload['amount_bif'] as num?)?.toDouble() ?? _amount;
            if (_method == 'bank') {
              context.push('/wallet/topup/bank', extra: {'amount': amt, 'coins': amt / price});
            } else {
              context.push(
                '/wallet/topup/sms',
                extra: {
                  'amount': amt,
                  'coins': amt / price,
                  'provider': _method,
                },
              );
            }
          }
        },
        builder: (context, state) {
          final loading = state is WalletLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Amount (BIF)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [500, 1000, 2000, 5000].map((v) {
                    final sel = _amount == v.toDouble();
                    return ChoiceChip(
                      label: Text('$v'),
                      selected: sel,
                      onSelected: (_) => setState(() => _amount = v.toDouble()),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom amount (BIF)',
                    hintText: 'e.g. 7500',
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null && n > 0) setState(() => _amount = n);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  '= ${coins.toStringAsFixed(coins == coins.roundToDouble() ? 0 : 1)} Regideso Coins = same litres',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 24),
                Text('Payment method', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Lumicash (USSD)'),
                        selected: _method == 'lumicash',
                        onSelected: loading ? null : (_) => setState(() => _method = 'lumicash'),
                      ),
                      ChoiceChip(
                        label: const Text('Ecocash (USSD)'),
                        selected: _method == 'ecocash',
                        onSelected: loading ? null : (_) => setState(() => _method = 'ecocash'),
                      ),
                      ChoiceChip(
                        label: const Text('Bank transfer'),
                        selected: _method == 'bank',
                        onSelected: loading ? null : (_) => setState(() => _method = 'bank'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () {
                          context.read<WalletBloc>().add(
                                WalletTopupSubmitted(amountBif: _amount, method: _method),
                              );
                        },
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.science_rounded, color: Colors.orange),
                  label: const Text(
                    'Simulate Payment (Sandbox)',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: loading ? null : () => context.push('/simulate/topup'),
                ),
                const SizedBox(height: 8),
                Text(
                  'API: ${ApiConfig.baseUrl}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
