import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/blocs/dispense/dispense_bloc.dart';
import 'package:majisafe_app/blocs/dispense/dispense_event.dart';
import 'package:majisafe_app/blocs/dispense/dispense_state.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/models/station.dart';
import 'package:majisafe_app/repositories/station_repository.dart';
import 'package:majisafe_app/widgets/station_status_badge.dart';

class BuyWaterScreen extends StatefulWidget {
  const BuyWaterScreen({super.key});

  @override
  State<BuyWaterScreen> createState() => _BuyWaterScreenState();
}

class _BuyWaterScreenState extends State<BuyWaterScreen> {
  List<Station> _stations = [];
  bool _loadingStations = true;
  String? _stationError;
  Station? _selected;
  double _litres = 5;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadStations();
    context.read<DispenseBloc>().add(const DispenseReset());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loadingStations = true;
      _stationError = null;
    });
    try {
      final list = await context.read<StationRepository>().listStations();
      if (!mounted) return;
      setState(() {
        _stations = list;
        _loadingStations = false;
        // Auto-select first available station
        _selected = list.firstWhere(
          (s) => s.status == 'online' || s.status == 'dispensing',
          orElse: () => list.isNotEmpty ? list.first : _selected!,
        );
      });
    } catch (e) {
      if (mounted) setState(() {
        _stationError = e.toString();
        _loadingStations = false;
      });
    }
  }

  void _startPoll(String txId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      context.read<DispenseBloc>().add(DispensePollTick(txId));
    });
  }

  double get _balance {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) return auth.user.coinBalance;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DispenseBloc, DispenseState>(
      listener: (context, state) {
        if (state is DispenseInProgress) {
          _startPoll(state.txId);
        }
        if (state is DispenseSuccess || state is DispenseFailure) {
          _poll?.cancel();
          context.read<WalletBloc>().add(const WalletLoadRequested());
          context.pushReplacement('/water/result');
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Buy Water')),
        body: BlocBuilder<DispenseBloc, DispenseState>(
          builder: (context, state) {
            final busy = state is DispenseRequesting || state is DispenseInProgress;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop_rounded, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Available: ${_balance.toStringAsFixed(0)} coins',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Station picker
                  Text('Select Station', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_loadingStations)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else if (_stationError != null)
                    _ErrorRetry(message: _stationError!, onRetry: _loadStations)
                  else if (_stations.isEmpty)
                    const Text('No stations available.')
                  else
                    ..._stations.map((s) => _StationTile(
                          station: s,
                          selected: _selected?.id == s.id,
                          onTap: busy ? null : () => setState(() => _selected = s),
                        )),

                  const SizedBox(height: 28),

                  // Litres slider
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
                          '${_litres.toInt()} coins = ${_litres.toInt()} L',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: _litres,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    activeColor: AppTheme.primary,
                    label: '${_litres.toInt()} L',
                    onChanged: busy ? null : (v) => setState(() => _litres = v.roundToDouble()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 L', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text('50 L', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quick chips
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 20, 30, 50].map((v) {
                      final sel = _litres == v.toDouble();
                      return ChoiceChip(
                        label: Text('${v}L'),
                        selected: sel,
                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                        onSelected: busy ? null : (_) => setState(() => _litres = v.toDouble()),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

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
                        _SummaryRow(label: 'Station', value: _selected?.name ?? _selected?.id ?? '—'),
                        _SummaryRow(label: 'Location', value: _selected?.location ?? '—'),
                        _SummaryRow(label: 'Coins to spend', value: '${_litres.toInt()}'),
                        _SummaryRow(label: 'You get', value: '${_litres.toInt()} litres'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Status message while dispensing
                  if (state is DispenseInProgress) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.progressLitres != null
                                  ? 'Dispensing… ${state.progressLitres!.toStringAsFixed(1)} / ${state.requestedLitres.toStringAsFixed(1)} L'
                                  : 'Dispensing… waiting for station',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.water_drop_rounded),
                      label: Text(busy ? 'Processing...' : 'Buy ${_litres.toInt()} litres'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: busy || _selected == null
                          ? null
                          : () {
                              if (_litres > _balance) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Insufficient coins. Please top up first.')),
                                );
                                return;
                              }
                              if (_selected!.status == 'offline' || _selected!.status == 'error') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Station ${_selected!.name ?? _selected!.id} is offline.')),
                                );
                                return;
                              }
                              context.read<DispenseBloc>()
                                ..add(DispenseStationSelected(_selected!))
                                ..add(DispenseLitresChanged(_litres))
                                ..add(const DispenseConfirmPressed());
                            },
                    ),
                  ),
                  if (_balance < _litres) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_card_rounded),
                        label: const Text('Top up coins'),
                        onPressed: () => context.push('/wallet/topup'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({required this.station, required this.selected, this.onTap});
  final Station station;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = station.status == 'online' || station.status == 'dispensing';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppTheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: available ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.water_drop_rounded,
                  color: available ? AppTheme.primary : AppTheme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name ?? station.id,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: available ? null : AppTheme.textMuted,
                        ),
                      ),
                      if (station.location != null)
                        Text(station.location!, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      if (station.tankLevel != null) ...[
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (station.tankLevel! / 100).clamp(0, 1),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(4),
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StationStatusBadge(status: station.status),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                ],
              ],
            ),
          ),
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

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(message, style: TextStyle(color: AppTheme.error)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
