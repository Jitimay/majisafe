import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the current [ThemeMode].
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  static const _key = 'theme_mode';

  /// Load saved preference on startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'dark') emit(ThemeMode.dark);
    else if (saved == 'light') emit(ThemeMode.light);
    else emit(ThemeMode.system);
  }

  Future<void> setLight() => _save(ThemeMode.light);
  Future<void> setDark() => _save(ThemeMode.dark);
  Future<void> setSystem() => _save(ThemeMode.system);

  Future<void> _save(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
