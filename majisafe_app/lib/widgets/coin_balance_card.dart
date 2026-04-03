import 'package:flutter/material.dart';
import 'package:majisafe_app/config/theme.dart';

/// Large animated Regideso Coins balance card.
class CoinBalanceCard extends StatelessWidget {
  const CoinBalanceCard({
    super.key,
    required this.coins,
    this.subtitle = 'Regideso Coins',
    this.footer,
  });

  final double coins;
  final String subtitle;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: coins),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                final text = value == value.roundToDouble()
                    ? value.toStringAsFixed(0)
                    : value.toStringAsFixed(1);
                return Text(
                  text,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                );
              },
            ),
            if (footer != null) ...[
              const SizedBox(height: 12),
              Text(
                footer!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
