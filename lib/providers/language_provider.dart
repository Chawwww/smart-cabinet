// lib/providers/language_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefsKey = 'selected_language_code';
  static const String _firstTimeKey = 'is_first_time_user';

  final SharedPreferences _prefs;
  Locale _currentLocale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale('ms'),
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': '中文',
    'ms': 'Bahasa Melayu',
  };

  static const Map<String, String> languageFlags = {
    'en': '🇬🇧',
    'zh': '🇨🇳',
    'ms': '🇲🇾',
  };

  static String normalizeLanguageCode(String? languageCode) {
    final cleaned = (languageCode ?? 'en').trim();
    if (cleaned.isEmpty) return 'en';

    final normalized = cleaned.toLowerCase();
    final mainCode = normalized.split('_').first.split('-').first;

    if (mainCode == 'en') return 'en';
    if (mainCode == 'zh') return 'zh';
    if (mainCode == 'ms') return 'ms';

    return 'en';
  }

  static Locale localeFromCode(String? languageCode) {
    final normalized = normalizeLanguageCode(languageCode);
    return Locale(normalized);
  }

  LanguageProvider(this._prefs)
      : _currentLocale = _getSavedLocale(_prefs);

  Locale get locale => _currentLocale;

  static Locale _getSavedLocale(SharedPreferences prefs) {
    final savedCode = prefs.getString(_prefsKey);
    return localeFromCode(savedCode);
  }

  Future<void> setLanguage(String languageCode) async {
    final normalizedCode = normalizeLanguageCode(languageCode);
    _currentLocale = Locale(normalizedCode);
    await _prefs.setString(_prefsKey, normalizedCode);
    notifyListeners();
  }

  Future<bool> isFirstTime() async {
    return _prefs.getBool(_firstTimeKey) ?? true;
  }

  Future<void> setFirstTimeComplete() async {
    await _prefs.setBool(_firstTimeKey, false);
  }

  String getCurrentLanguageName() {
    return languageNames[_currentLocale.languageCode] ?? 'English';
  }

  String getCurrentLanguageFlag() {
    return languageFlags[_currentLocale.languageCode] ?? '🇬🇧';
  }

  bool isSelected(String languageCode) {
    return _currentLocale.languageCode == languageCode;
  }

  // ── Clear Data on Logout ───────────────────────────────
  void clearData() {
    // Language persists across logins
    // No action needed
  }
}