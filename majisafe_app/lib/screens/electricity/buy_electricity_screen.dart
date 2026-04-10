import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/electricity/electricity_bloc.dart';
import 'package:majisafe_app/blocs/electricity/electricity_event.dart';
import 'package:majisafe_app/blocs/electricity/electricity_state.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/config/theme.dart';

class BuyElectricityScreen extends StatefulWidget {
  const BuyElectricityScreen({super.key});

  @override
  State<BuyElectricityScreen> createState() => _BuyElectricityScreenState();
}

class _BuyElectricityScreenState extends State<BuyElectricityScreen> {
  final _meterCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _coins = 10;

  @override
  void dispose() {
    _meterCtrl.dispose();
    super.dispose();
  }

  double get _balance {
    final w = context.read<WalletBloc>().state;
    if (w is WalletLoaded) return w.coins;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ElectricityBloc, ElectricityState>(
      listener: (context, state) {
        if (state is ElectricitySuccess) {
          context.pushReplacement('/electricity/result', extra: state.order);
        } else if (state is ElectricityFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.error),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Buy Electricity')),
        body: BlocBuilder<ElectricityBloc, ElectricityState>(
          builder: (context, state) {
            final loading = state is ElectricityLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 10),
                          Text(
                            'Available: ${_balance.toStringAsFixed(0)} coins',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Meter Number', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _meterCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'e.g. 12345678',
                        prefixIcon: Icon(Icons.electric_meter_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter meter number';
                        if (v.trim().length < 6) return 'Meter number too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_coins.toInt()} coins = ${_coins.toInt()} kWh',
                            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _coins,
                      min: 1,
                      max: 500,
                      divisions: 499,
                      activeColor: const Color(0xFFF59E0B),
                      label: '${_coins.toInt()} coins',
                      onChanged: loading ? null : (v) => setState(() => _coins = v.roundToDouble()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 coin', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        Text('500 coins', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick amount chips
                    Wrap(
                      spacing: 8,
                      children: [10, 20, 50, 100, 200].map((v) {
                        final selected = _coins == v.toDouble();
                        return ChoiceChip(
                          label: Text('$v'),
                          selected: selected,
                          selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          onSelected: loading ? null : (_) => setState(() => _coins = v.toDouble()),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          _SummaryRow(label: 'Meter', value: _meterCtrl.text.isEmpty ? '—' : _meterCtrl.text),
                          _SummaryRow(label: 'Coins to spend', value: '${_coins.toInt()}'),
                          _SummaryRow(label: 'You get', value: '${_coins.toInt()} kWh'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.bolt_rounded),
                        label: Text(loading ? 'Processing...' : 'Buy ${_coins.toInt()} kWh'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: loading
                            ? null
                            : () {
                                if (!_formKey.currentState!.validate()) return;
                                if (_coins > _balance) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Insufficient coins. Please top up first.')),
                                  );
                                  return;
                                }
                                context.read<ElectricityBloc>().add(
                                      ElectricityBuyPressed(
                                        meterNumber: _meterCtrl.text.trim(),
                                        coins: _coins,
                                      ),
                                    );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
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
