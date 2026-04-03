import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/widgets/error_snackbar.dart';

/// New user registration for MajiSafe.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (p, c) =>
            (c is AuthUnauthenticated && (p is AuthLoading || p is AuthUnauthenticated)) ||
            (p is AuthLoading && c is AuthAuthenticated && c.justRegistered),
        listener: (context, state) {
          if (state is AuthUnauthenticated && state.message != null) {
            showErrorSnackBar(context, state.message!);
          }
          if (state is AuthAuthenticated && state.justRegistered) {
            final n = state.user.name?.trim();
            final label = (n != null && n.isNotEmpty) ? n : state.user.phone;
            showSuccessSnackBarGlobal('Welcome, $label! Your Regideso Wallet is ready.');
            context.read<AuthBloc>().add(const AuthJustRegisteredAcknowledged());
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Enter a valid phone' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
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
                                  AuthRegisterSubmitted(
                                    phone: _phone.text.trim(),
                                    name: _name.text.trim(),
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
                        : const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: loading ? null : () => context.pop(),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
