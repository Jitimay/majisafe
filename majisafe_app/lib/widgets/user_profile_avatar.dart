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
    /// When true, always requests the avatar endpoint (e.g. Profile tab) so the
    /// image still shows if `has_avatar` on [user] was stale or missing.
    this.probeServerEvenIfNoFlag = false,
  });

  final User user;
  final double radius;
  final bool probeServerEvenIfNoFlag;

  @override
  State<UserProfileAvatar> createState() => _UserProfileAvatarState();
}

class _UserProfileAvatarState extends State<UserProfileAvatar> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.probeServerEvenIfNoFlag || widget.user.hasAvatar) {
      _loading = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(UserProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.hasAvatar != widget.user.hasAvatar ||
        oldWidget.probeServerEvenIfNoFlag != widget.probeServerEvenIfNoFlag) {
      _bytes = null;
      _loading = widget.probeServerEvenIfNoFlag || widget.user.hasAvatar;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Uint8List? _bytesFromResponse(dynamic raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  Future<void> _load() async {
    final shouldFetch = widget.probeServerEvenIfNoFlag || widget.user.hasAvatar;
    if (!shouldFetch) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    try {
      final dio = context.read<ApiService>().client;
      final res = await dio.get<dynamic>(
        ApiConfig.authAvatar,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: widget.probeServerEvenIfNoFlag
              ? (s) => s != null && (s == 200 || s == 404)
              : null,
        ),
      );
      if (widget.probeServerEvenIfNoFlag && res.statusCode == 404) {
        if (mounted) {
          setState(() {
            _bytes = null;
            _loading = false;
          });
        }
        return;
      }
      final parsed = _bytesFromResponse(res.data);
      if (parsed != null && parsed.isNotEmpty) {
        if (mounted) {
          setState(() {
            _bytes = parsed;
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
        });
      }
    }
  }

  Widget _initialsAvatar(double r) {
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

    if (_bytes != null && _bytes!.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          _bytes!,
          width: r * 2,
          height: r * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _initialsAvatar(r),
        ),
      );
    }

    if (_loading) {
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

    if (!widget.probeServerEvenIfNoFlag && !widget.user.hasAvatar) {
      return _initialsAvatar(r);
    }

    // Probed or had flag but no bytes (404, parse error, or network failure).
    return _initialsAvatar(r);
  }
}
