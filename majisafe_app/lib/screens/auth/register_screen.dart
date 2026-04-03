import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:majisafe_app/blocs/auth/auth_bloc.dart';
import 'package:majisafe_app/blocs/auth/auth_event.dart';
import 'package:majisafe_app/blocs/auth/auth_state.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/widgets/error_snackbar.dart';

/// New user registration for MajiSafe.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const int _maxAvatarBytes = 400 * 1024;

  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _picker = ImagePicker();

  Uint8List? _avatarBytes;
  String? _avatarMime;

  String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 82,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > _maxAvatarBytes) {
      if (mounted) {
        showErrorSnackBar(context, 'Photo must be under 400 KB. Try a smaller image or lower quality.');
      }
      return;
    }
    setState(() {
      _avatarBytes = bytes;
      _avatarMime = _mimeForPath(x.path);
    });
  }

  void _showAvatarSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (_avatarBytes != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                title: Text('Remove photo', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _avatarBytes = null;
                    _avatarMime = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

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
      appBar: AppBar(
        title: const Text('Create account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join MajiSafe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'One account for Regideso Coins and water dispensing.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showAvatarSourceSheet,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                                backgroundImage:
                                    _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                                child: _avatarBytes == null
                                    ? Icon(Icons.add_a_photo_outlined, size: 36, color: AppTheme.secondary)
                                    : null,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Material(
                                  color: AppTheme.primary,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _showAvatarSourceSheet,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Profile photo (optional)',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Enter a valid phone' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
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
                                    avatarBytes: _avatarBytes?.toList(),
                                    avatarMime: _avatarMime,
                                  ),
                                );
                          },
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 8),
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
