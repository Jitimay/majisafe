import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/widgets/error_snackbar.dart';

/// Phone + password sign-in for Regideso Wallet.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (p, c) =>
            c is AuthUnauthenticated && (p is AuthLoading || p is AuthUnauthenticated),
        listener: (context, state) {
          if (state is AuthUnauthenticated && state.message != null) {
            showErrorSnackBar(context, state.message!);
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.water_drop, size: 72, color: AppTheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        'Regideso Wallet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your phone',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        validator: (v) =>
                            (v == null || v.length < 8) ? 'Enter a valid phone' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: loading
                            ? null
                            : () {
                                if (!_form.currentState!.validate()) return;
                                context.read<AuthBloc>().add(
                                      AuthLoginSubmitted(
                                        phone: _phone.text.trim(),
                                        password: _password.text,
                                      ),
                                    );
                              },
                        child: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign in'),
                      ),
                      TextButton(
                        onPressed: loading ? null : () => context.push('/register'),
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
