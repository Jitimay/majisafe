import 'package:flutter/material.dart';
import 'package:majisafe_app/config/theme.dart';

/// Shown while [AuthBloc] restores the session from secure storage.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop, size: 64, color: AppTheme.primary),
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Regideso Wallet'),
          ],
        ),
      ),
    );
  }
}
