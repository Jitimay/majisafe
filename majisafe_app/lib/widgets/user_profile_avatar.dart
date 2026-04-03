import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/config/theme.dart';
import 'package:majisafe_app/models/user.dart';
import 'package:majisafe_app/services/api_service.dart';

/// Loads the signed-in user's avatar from `GET /api/auth/avatar` (Bearer required).
class UserProfileAvatar extends StatefulWidget {
  const UserProfileAvatar({
    super.key,
    required this.user,
    this.radius = 28,
    this.fallbackIconSize,
  });

  final User user;
  final double radius;
  final double? fallbackIconSize;

  @override
  State<UserProfileAvatar> createState() => _UserProfileAvatarState();
}

class _UserProfileAvatarState extends State<UserProfileAvatar> {
  Uint8List? _bytes;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(UserProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.user.hasAvatar != widget.user.hasAvatar) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.user.hasAvatar) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final dio = context.read<ApiService>().client;
      final res = await dio.get<dynamic>(
        ApiConfig.authAvatar,
        options: Options(responseType: ResponseType.bytes),
      );
      final raw = res.data;
      if (raw is List<int>) {
        if (mounted) {
          setState(() {
            _bytes = Uint8List.fromList(raw);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String _initials() {
    final n = widget.user.name?.trim();
    if (n != null && n.isNotEmpty) {
      final parts = n.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      if (n.length >= 2) return n.substring(0, 2).toUpperCase();
      return n[0].toUpperCase();
    }
    final p = widget.user.phone;
    if (p.length >= 2) return p.substring(p.length - 2);
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;
    final iconSize = widget.fallbackIconSize ?? (r * 1.1);

    if (!widget.user.hasAvatar || _failed) {
      return CircleAvatar(
        radius: r,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
        child: Text(
          _initials(),
          style: TextStyle(
            fontSize: r * 0.85,
            fontWeight: FontWeight.w800,
            color: AppTheme.secondary,
          ),
        ),
      );
    }

    if (_loading && _bytes == null) {
      return CircleAvatar(
        radius: r,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        child: SizedBox(
          width: r * 0.9,
          height: r * 0.9,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_bytes != null && _bytes!.isNotEmpty) {
      return CircleAvatar(
        radius: r,
        backgroundImage: MemoryImage(_bytes!),
      );
    }

    return CircleAvatar(
      radius: r,
      backgroundColor: AppTheme.secondary.withValues(alpha: 0.12),
      child: Icon(Icons.person_rounded, size: iconSize, color: AppTheme.secondary),
    );
  }
}
