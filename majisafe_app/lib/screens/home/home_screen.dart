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
import 'package:majisafe_app/models/user.dart';
import 'package:majisafe_app/widgets/coin_balance_card.dart';
import 'package:majisafe_app/widgets/user_profile_avatar.dart';
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
    final User? user = auth is AuthAuthenticated ? auth.user : null;
    final name = user != null ? (user.name ?? user.phone) : '';

    return Scaffold(
      appBar: AppBar(title: const Text('MajiSafe')),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.12),
                        AppTheme.secondary.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user != null) ...[
                        UserProfileAvatar(user: user, radius: 30),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $name',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.secondary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMEd().add_jm().format(DateTime.now()),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (banner != null) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, color: Colors.amber.shade900, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(banner, style: TextStyle(color: Colors.amber.shade900, fontSize: 13)),
                          ),
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
                const SizedBox(height: 22),
                Text('Services', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ServiceCard(
                        icon: Icons.water_drop_rounded,
                        label: 'Buy Water',
                        description: '1 coin = 1 litre',
                        color: const Color(0xFF1D9E75),
                        onTap: () => context.push('/water/buy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ServiceCard(
                        icon: Icons.bolt_rounded,
                        label: 'Buy Electricity',
                        description: 'Pay with coins',
                        color: const Color(0xFFF59E0B),
                        onTap: () => context.push('/electricity/buy'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Quick actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HomeActionCard(
                        icon: Icons.add_card_rounded,
                        label: 'Top up',
                        onTap: () => context.push('/wallet/topup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HomeActionCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'History',
                        onTap: () => context.go('/history'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text('Last activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (w is WalletLoading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (txs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: comingSoon ? 0.07 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: comingSoon ? 0.15 : 0.25)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  if (comingSoon)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Soon', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: comingSoon ? AppTheme.textMuted : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 14 : 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primary, size: dense ? 22 : 26),
              ),
              SizedBox(width: dense ? 12 : 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 14 : 15,
                    color: AppTheme.secondary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
