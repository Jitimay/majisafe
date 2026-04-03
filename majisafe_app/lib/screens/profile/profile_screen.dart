import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';

/// Profile and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AuthBloc>().state;
    if (s is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final u = s.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(title: const Text('Name'), subtitle: Text(u.name ?? '—')),
          ListTile(title: const Text('Phone'), subtitle: Text(u.phone)),
          ListTile(title: const Text('Role'), subtitle: Text(u.role)),
          ListTile(
            title: const Text('Coins'),
            subtitle: Text(u.coinBalance.toStringAsFixed(2)),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutPressed());
              context.go('/login');
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
