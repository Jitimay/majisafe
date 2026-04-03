import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/blocs/wallet/wallet_state.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/repositories/station_repository.dart';
import 'package:majisafe_app/models/transaction.dart';
import 'package:majisafe_app/widgets/coin_balance_card.dart';
import 'package:majisafe_app/widgets/transaction_tile.dart';

/// Dashboard: greeting, balance, quick actions, last transaction, station count.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _activeStations;

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletLoadRequested());
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final repo = context.read<StationRepository>();
      final list = await repo.listStations();
      if (!mounted) return;
      final n = list.where((s) => s.status == 'online' || s.status == 'dispensing').length;
      setState(() => _activeStations = n);
    } catch (_) {
      if (mounted) setState(() => _activeStations = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final name = auth is AuthAuthenticated ? (auth.user.name ?? auth.user.phone) : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('MajiSafe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/wallet'),
            tooltip: 'Wallet',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<WalletBloc>().add(const WalletLoadRequested());
          await _loadStations();
        },
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, w) {
            double coins = 0;
            var txs = <WalletTransaction>[];
            String? banner;
            if (w is WalletLoaded) {
              coins = w.coins;
              txs = w.transactions;
              banner = w.offlineBanner;
            } else if (w is WalletFailure && w.cachedCoins != null) {
              coins = w.cachedCoins!;
              banner = 'Offline — cached balance';
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Hello, $name',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat.jm().format(DateTime.now()),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (banner != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(child: Text(banner)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                CoinBalanceCard(
                  coins: coins,
                  footer: _activeStations != null ? '$_activeStations station(s) active' : null,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ActionChip(
                      icon: Icons.water_drop,
                      label: 'Dispense Water',
                      onTap: () => context.push('/dispense/stations'),
                    ),
                    _ActionChip(
                      icon: Icons.add_card,
                      label: 'Top Up',
                      onTap: () => context.push('/wallet/topup'),
                    ),
                    _ActionChip(
                      icon: Icons.history,
                      label: 'History',
                      onTap: () => context.push('/history'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Last activity', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (w is WalletLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (txs.isEmpty)
                  Text('No transactions yet', style: TextStyle(color: Colors.grey.shade600))
                else
                  Card(
                    child: TransactionTile(tx: txs.first),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
