import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MajiSafe Regideso Wallet theme (teal water palette, Inter via Google Fonts).
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1D9E75);
  static const Color secondary = Color(0xFF0F6E56);
  static const Color background = Color(0xFFF8FFFE);
  static const Color error = Color(0xFFE24B4A);

  /// Builds the root Material 3 theme for the app.
  static ThemeData light() {
    final textTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: background,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
