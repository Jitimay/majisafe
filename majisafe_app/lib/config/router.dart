import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/config/go_router_refresh.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/models/station.dart';
import 'package:majisafe_app/models/transaction.dart';
import 'package:majisafe_app/screens/auth/login_screen.dart';
import 'package:majisafe_app/screens/auth/register_screen.dart';
import 'package:majisafe_app/screens/dispense/dispense_result_screen.dart';
import 'package:majisafe_app/screens/dispense/dispense_screen.dart';
import 'package:majisafe_app/screens/dispense/station_detail_screen.dart';
import 'package:majisafe_app/screens/dispense/station_list_screen.dart';
import 'package:majisafe_app/screens/history/history_screen.dart';
import 'package:majisafe_app/screens/history/transaction_detail_screen.dart';
import 'package:majisafe_app/screens/home/home_screen.dart';
import 'package:majisafe_app/screens/profile/profile_screen.dart';
import 'package:majisafe_app/screens/splash_screen.dart';
import 'package:majisafe_app/screens/wallet/topup_bank_screen.dart';
import 'package:majisafe_app/screens/wallet/topup_screen.dart';
import 'package:majisafe_app/screens/wallet/topup_sms_screen.dart';
import 'package:majisafe_app/screens/wallet/wallet_screen.dart';

/// Builds [GoRouter] with auth redirects and app routes.
GoRouter createRouter({
  required AuthBloc authBloc,
  required GoRouterRefreshStream refresh,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final loc = state.matchedLocation;
      final authState = context.read<AuthBloc>().state;
      final isAuth = authState is AuthAuthenticated;
      final isLogin = loc == '/login' || loc == '/register';
      if (authState is AuthInitial || authState is AuthLoading) {
        final public = loc == '/splash' || loc == '/login' || loc == '/register';
        return public ? null : '/splash';
      }
      if (isAuth) {
        if (isLogin || loc == '/splash') return '/home';
        return null;
      }
      if (authState is AuthUnauthenticated) {
        if (!isLogin && loc != '/splash') return '/login';
        if (loc == '/splash') return '/login';
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/wallet/topup', builder: (_, __) => const TopUpScreen()),
      GoRoute(
        path: '/wallet/topup/sms',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          if (extra == null) return const Scaffold(body: Center(child: Text('Missing data')));
          return TopUpSmsScreen(
            amountBif: (extra['amount'] as num).toDouble(),
            coins: (extra['coins'] as num).toDouble(),
            provider: extra['provider'] as String? ?? 'lumicash',
          );
        },
      ),
      GoRoute(
        path: '/wallet/topup/bank',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          if (extra == null) return const Scaffold(body: Center(child: Text('Missing data')));
          return TopUpBankScreen(
            amountBif: (extra['amount'] as num).toDouble(),
            coins: (extra['coins'] as num).toDouble(),
          );
        },
      ),
      GoRoute(path: '/dispense/stations', builder: (_, __) => const StationListScreen()),
      GoRoute(
        path: '/dispense/detail',
        builder: (c, s) {
          final st = s.extra as Station?;
          if (st == null) return const Scaffold(body: Center(child: Text('No station')));
          return StationDetailScreen(station: st);
        },
      ),
      GoRoute(path: '/dispense/run', builder: (_, __) => const DispenseScreen()),
      GoRoute(path: '/dispense/result', builder: (_, __) => const DispenseResultScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(
        path: '/history/detail',
        builder: (c, s) {
          final tx = s.extra as WalletTransaction?;
          if (tx == null) return const Scaffold(body: Center(child: Text('No transaction')));
          return TransactionDetailScreen(tx: tx);
        },
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
}

/// Root [MaterialApp.router] with MajiSafe theme.
class RegidesoApp extends StatelessWidget {
  const RegidesoApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Regideso Wallet',
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
