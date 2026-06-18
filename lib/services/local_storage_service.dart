import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static final LocalStorageService _instance =
      LocalStorageService._internal();

  factory LocalStorageService() => _instance;

  LocalStorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception(
        'LocalStorageService not initialized. Call init() first.',
      );
    }

    return _prefs!;
  }

  // ==========================
  // String
  // ==========================

  Future<bool> setString(
    String key,
    String value,
  ) async {
    return prefs.setString(key, value);
  }

  String? getString(String key) {
    return prefs.getString(key);
  }

  // ==========================
  // Bool
  // ==========================

  Future<bool> setBool(
    String key,
    bool value,
  ) async {
    return prefs.setBool(key, value);
  }

  bool getBool(
    String key, {
    bool defaultValue = false,
  }) {
    return prefs.getBool(key) ?? defaultValue;
  }

  // ==========================
  // Int
  // ==========================

  Future<bool> setInt(
    String key,
    int value,
  ) async {
    return prefs.setInt(key, value);
  }

  int getInt(
    String key, {
    int defaultValue = 0,
  }) {
    return prefs.getInt(key) ?? defaultValue;
  }

  // ==========================
  // Double
  // ==========================

  Future<bool> setDouble(
    String key,
    double value,
  ) async {
    return prefs.setDouble(key, value);
  }

  double getDouble(
    String key, {
    double defaultValue = 0,
  }) {
    return prefs.getDouble(key) ?? defaultValue;
  }

  // ==========================
  // List<String>
  // ==========================

  Future<bool> setStringList(
    String key,
    List<String> value,
  ) async {
    return prefs.setStringList(key, value);
  }

  List<String> getStringList(String key) {
    return prefs.getStringList(key) ?? [];
  }

  // ==========================
  // Map<String,dynamic>
  // ==========================

  Future<bool> setMap(
    String key,
    Map<String, dynamic> value,
  ) async {
    return prefs.setString(
      'map_$key',
      jsonEncode(value),
    );
  }

  Map<String, dynamic>? getMap(String key) {
    final json = prefs.getString('map_$key');

    if (json == null) return null;

    try {
      return Map<String, dynamic>.from(
        jsonDecode(json),
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // Generic Object
  // ==========================

  Future<bool> setObject(
    String key,
    dynamic object,
  ) async {
    return prefs.setString(
      'obj_$key',
      jsonEncode(object),
    );
  }

  dynamic getObject(String key) {
    final json = prefs.getString('obj_$key');

    if (json == null) return null;

    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // Remove
  // ==========================

  Future<bool> remove(String key) async {
    return prefs.remove(key);
  }

  // ==========================
  // Clear
  // ==========================

  Future<bool> clear() async {
    return prefs.clear();
  }

  // ==========================
  // Contains Key
  // ==========================

  bool containsKey(String key) {
    return prefs.containsKey(key);
  }

  // ==========================
  // Get All Keys
  // ==========================

  Set<String> getKeys() {
    return prefs.getKeys();
  }

  // ==========================
  // Common Smart Cabinet Keys
  // ==========================

  static const String darkModeKey = "dark_mode";

  static const String firstLaunchKey = "first_launch";

  static const String aiChatHistoryKey = "ai_chat_history";

  static const String lastConnectedDeviceKey =
      "last_connected_device";

  static const String notificationsEnabledKey =
      "notifications_enabled";

  static const String biometricEnabledKey =
      "biometric_enabled";

  static const String languageKey = "language";
}