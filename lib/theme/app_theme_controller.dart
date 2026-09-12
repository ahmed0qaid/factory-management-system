import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  AppThemeController._();

  static const _preferenceKey = 'app_theme_mode';
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = _decode(prefs.getString(_preferenceKey));
  }

  static Future<void> setMode(ThemeMode value) async {
    if (mode.value == value) return;
    mode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, _encode(value));
  }

  static String _encode(ThemeMode value) => switch (value) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decode(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
