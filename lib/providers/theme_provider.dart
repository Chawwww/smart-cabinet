// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';

  final SharedPreferences prefs;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider(this.prefs) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void _loadTheme() {
    final bool darkMode = prefs.getBool(_themeKey) ?? false;
    _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await prefs.setBool(_themeKey, mode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setLightMode() async {
    _themeMode = ThemeMode.light;
    await prefs.setBool(_themeKey, false);
    notifyListeners();
  }

  Future<void> setDarkMode() async {
    _themeMode = ThemeMode.dark;
    await prefs.setBool(_themeKey, true);
    notifyListeners();
  }
}