import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_event.dart';
import 'package:majisafe_app/config/theme.dart';

/// Main tabs: floating rounded [NavigationBar] with side/bottom inset (does not touch screen edges).
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: AppTheme.textMuted),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: AppTheme.primary),
      label: 'Home',
    ),
    NavigationDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedWallet01, color: AppTheme.textMuted),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedWallet01, color: AppTheme.primary),
      label: 'Wallet',
    ),
    NavigationDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedTransaction, color: AppTheme.textMuted),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedTransaction, color: AppTheme.primary),
      label: 'History',
    ),
    NavigationDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedUser, color: AppTheme.textMuted),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedUser, color: AppTheme.primary),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomInset = viewPadding.bottom;
    const horizontalInset = 20.0;
    const verticalBarGap = 12.0;
    const barHeight = 72.0;
    final contentBottomPad = barHeight + verticalBarGap * 2 + bottomInset + 8;

    return Scaffold(
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(bottom: contentBottomPad),
        child: navigationShell,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          0,
          horizontalInset,
          verticalBarGap + bottomInset,
        ),
        child: Material(
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(28),
          color: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: barHeight,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: AppTheme.primary.withValues(alpha: 0.18),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.secondary : AppTheme.textMuted,
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      color: selected ? AppTheme.primary : AppTheme.textMuted,
                      size: 24,
                    );
                  }),
                ),
                child: NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                    if (index == 1 && context.mounted) {
                      context.read<WalletBloc>().add(const WalletLoadRequested());
                    }
                  },
                  destinations: _destinations,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
