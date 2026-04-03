import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/widgets/user_profile_avatar.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primary.withValues(alpha: 0.2), AppTheme.secondary.withValues(alpha: 0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: UserProfileAvatar(user: u, radius: 52, fallbackIconSize: 52),
            ),
          ),
          const SizedBox(height: 20),
          _ProfileTile(icon: Icons.badge_outlined, title: 'Name', value: u.name ?? '—'),
          _ProfileTile(icon: Icons.phone_android_rounded, title: 'Phone', value: u.phone),
          _ProfileTile(icon: Icons.verified_user_outlined, title: 'Role', value: u.role),
          _ProfileTile(
            icon: Icons.savings_outlined,
            title: 'Regideso Coins',
            value: u.coinBalance.toStringAsFixed(2),
          ),
          const SizedBox(height: 28),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppTheme.error,
              backgroundColor: AppTheme.error.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
