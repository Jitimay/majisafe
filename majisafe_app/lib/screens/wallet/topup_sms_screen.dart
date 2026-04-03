import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/config/api_config.dart';

/// Step-by-step USSD instructions and optional balance polling.
class TopUpSmsScreen extends StatefulWidget {
  const TopUpSmsScreen({
    super.key,
    required this.amountBif,
    required this.coins,
    required this.provider,
  });

  final double amountBif;
  final double coins;
  final String provider;

  @override
  State<TopUpSmsScreen> createState() => _TopUpSmsScreenState();
}

class _TopUpSmsScreenState extends State<TopUpSmsScreen> {
  Timer? _poll;
  double? _lastCoins;
  bool _done = false;
  int _ticks = 0;
  static const int _maxTicks = 30; // 10s × 30 ≈ 5 minutes

  @override
  void initState() {
    super.initState();
    final w = context.read<WalletBloc>().state;
    if (w is WalletLoaded) _lastCoins = w.coins;
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!mounted || _done) return;
    _ticks++;
    if (_ticks > _maxTicks) {
      _poll?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Polling stopped after 5 minutes.')),
        );
      }
      return;
    }
    context.read<WalletBloc>().add(const WalletLoadRequested());
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final s = context.read<WalletBloc>().state;
    if (s is WalletLoaded && _lastCoins != null && s.coins > _lastCoins!) {
      setState(() => _done = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance updated — coins credited.')),
        );
        context.pop();
        context.pop();
      }
    }
    if (s is WalletLoaded) _lastCoins = s.coins;
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEco = widget.provider == 'ecocash';
    final ussd = isEco ? '*150#' : '*144#';
    return Scaffold(
      appBar: AppBar(title: const Text('Pay with USSD')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Follow these steps', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _Step(n: 1, text: 'Dial $ussd (${isEco ? 'Ecocash' : 'Lumicash'}).'),
          _Step(n: 2, text: 'Choose “Send Money”.'),
          _Step(
            n: 3,
            text: 'Send to REGIDESO number: ${ApiConfig.regidesoMerchantPhone}',
          ),
          _Step(n: 4, text: 'Amount: ${widget.amountBif.toStringAsFixed(0)} BIF'),
          const _Step(
            n: 5,
            text: 'Coins are usually credited within 60 seconds after the SMS is received.',
          ),
          const SizedBox(height: 24),
          if (!_done)
            const Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Checking balance every 10s (up to 5 min)…')),
              ],
            )
          else
            const Text('Done.'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              _poll?.cancel();
              context.pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, child: Text('$n', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
