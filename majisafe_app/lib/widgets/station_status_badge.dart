import 'package:flutter/material.dart';
import 'package:majisafe_app/config/theme.dart';

/// Colored pill for station operational status.
class StationStatusBadge extends StatelessWidget {
  const StationStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _map(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  (String, Color) _map(String s) {
    switch (s) {
      case 'online':
        return ('Online', AppTheme.primary);
      case 'dispensing':
        return ('Dispensing', Colors.amber.shade800);
      case 'error':
        return ('Error', AppTheme.error);
      default:
        return ('Offline', AppTheme.error);
    }
  }
}
