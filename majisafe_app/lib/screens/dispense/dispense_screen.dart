import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/blocs/dispense/dispense_bloc.dart';
import 'package:majisafe_app/blocs/dispense/dispense_event.dart';
import 'package:majisafe_app/blocs/dispense/dispense_state.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/widgets/loading_overlay.dart';
import 'package:majisafe_app/widgets/station_status_badge.dart';

/// Litre selector, confirm, and polling until terminal dispense status.
class DispenseScreen extends StatefulWidget {
  const DispenseScreen({super.key});

  @override
  State<DispenseScreen> createState() => _DispenseScreenState();
}

class _DispenseScreenState extends State<DispenseScreen> {
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPoll(String txId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      context.read<DispenseBloc>().add(DispensePollTick(txId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DispenseBloc, DispenseState>(
      listenWhen: (p, c) {
        if (c is DispenseInProgress && p is! DispenseInProgress) return true;
        if (c is DispenseSuccess && p is! DispenseSuccess) return true;
        if (c is DispenseFailure && p is! DispenseFailure) return true;
        return false;
      },
      listener: (context, state) {
        if (state is DispenseInProgress) {
          _startPoll(state.txId);
        }
        if (state is DispenseSuccess || state is DispenseFailure) {
          _poll?.cancel();
          context.read<WalletBloc>().add(const WalletLoadRequested());
          context.read<AuthBloc>().add(const AuthSilentRefresh());
          if (mounted) context.push('/dispense/result');
        }
      },
      builder: (context, state) {
        if (state is DispenseInitial) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dispense')),
            body: const Center(child: Text('Select a station first.')),
          );
        }
        if (state is DispenseSelecting) {
          return _SelectingBody(state: state);
        }
        if (state is DispenseRequesting) {
          return LoadingOverlay(
            visible: true,
            message: 'Connecting to station…',
            child: _SelectingBody(
              state: DispenseSelecting(station: state.station, litres: state.litres),
            ),
          );
        }
        if (state is DispenseInProgress) {
          final prog = state.progressLitres;
          final target = state.requestedLitres;
          final line = prog != null
              ? 'Dispensing… ${prog.toStringAsFixed(1)} / ${target.toStringAsFixed(1)} L'
              : 'Dispensing… up to ${target.toStringAsFixed(1)} L';
          return LoadingOverlay(
            visible: true,
            message: line,
            child: Scaffold(
              appBar: AppBar(title: Text(state.station.name ?? state.station.id)),
              body: const SizedBox.expand(),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _SelectingBody extends StatefulWidget {
  const _SelectingBody({required this.state});

  final DispenseSelecting state;

  @override
  State<_SelectingBody> createState() => _SelectingBodyState();
}

class _SelectingBodyState extends State<_SelectingBody> {
  late double _litres;

  @override
  void initState() {
    super.initState();
    _litres = widget.state.litres;
  }

  @override
  void didUpdateWidget(covariant _SelectingBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.litres != widget.state.litres) {
      _litres = widget.state.litres;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state.station;
    final auth = context.watch<AuthBloc>().state;
    final balance = auth is AuthAuthenticated ? auth.user.coinBalance : 0.0;
    final enough = balance >= _litres;

    return Scaffold(
      appBar: AppBar(title: Text(s.name ?? s.id)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              StationStatusBadge(status: s.status),
              const SizedBox(width: 8),
              Text('Balance: ${balance.toStringAsFixed(1)} coins'),
            ],
          ),
          const SizedBox(height: 24),
          Text('Litres (1–50)', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _litres.clamp(1, 50),
            min: 1,
            max: 50,
            divisions: 49,
            label: _litres.toStringAsFixed(1),
            onChanged: (v) {
              setState(() => _litres = v);
              context.read<DispenseBloc>().add(DispenseLitresChanged(v));
            },
          ),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Manual litres'),
            onChanged: (v) {
              final n = double.tryParse(v);
              if (n != null && n >= 1 && n <= 50) {
                setState(() => _litres = n);
                context.read<DispenseBloc>().add(DispenseLitresChanged(n));
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            '${_litres.toStringAsFixed(1)} coins will be deducted',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          if (!enough)
            FilledButton.tonal(
              onPressed: () => context.push('/wallet/topup'),
              child: const Text('Top Up'),
            )
          else
            FilledButton(
              onPressed: () {
                context.read<DispenseBloc>().add(const DispenseConfirmPressed());
              },
              child: const Text('Confirm & dispense'),
            ),
        ],
      ),
    );
  }
}
