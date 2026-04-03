import 'package:flutter/material.dart';
import 'package:majisafe_app/config/theme.dart';

/// Shows a short error snackbar using the app error color.
void showErrorSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
