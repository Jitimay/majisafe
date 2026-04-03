import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/dispense/dispense_bloc.dart';
import 'package:majisafe_app/blocs/wallet/wallet_bloc.dart';
import 'package:majisafe_app/config/go_router_refresh.dart';
import 'package:majisafe_app/config/router.dart';
import 'package:majisafe_app/repositories/auth_repository.dart';
import 'package:majisafe_app/repositories/dispense_repository.dart';
import 'package:majisafe_app/repositories/station_repository.dart';
import 'package:majisafe_app/repositories/wallet_repository.dart';
import 'package:majisafe_app/services/api_service.dart';
import 'package:majisafe_app/services/auth_service.dart';
import 'package:majisafe_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  final authService = AuthService();
  final apiService = ApiService(authService: authService);
  final authRepository = AuthRepository(apiService: apiService, authService: authService);
  final walletRepository = WalletRepository(apiService: apiService);
  final stationRepository = StationRepository(apiService: apiService);
  final dispenseRepository = DispenseRepository(apiService: apiService);

  final authBloc = AuthBloc(authRepository: authRepository, authService: authService)
    ..add(const AuthCheckRequested());

  final refresh = GoRouterRefreshStream(authBloc.stream);
  final router = createRouter(authBloc: authBloc, refresh: refresh);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<WalletRepository>.value(value: walletRepository),
        RepositoryProvider<StationRepository>.value(value: stationRepository),
        RepositoryProvider<DispenseRepository>.value(value: dispenseRepository),
        RepositoryProvider<ApiService>.value(value: apiService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider(
            create: (_) => WalletBloc(repository: walletRepository),
          ),
          BlocProvider(
            create: (_) => DispenseBloc(repository: dispenseRepository),
          ),
        ],
        child: RegidesoApp(router: router),
      ),
    ),
  );
}
