// lib/services/location_memory_service.dart
//
// Remembers the last cabinet/box the user picked when adding an item,
// so the next "Add Item" screen starts pre-filled with it instead of
// blank. Read on screen init, written whenever an item is saved.

import 'package:shared_preferences/shared_preferences.dart';

class LocationMemoryService {
  static const _kCabinetKey = 'last_used_cabinet_id';
  static const _kBoxKey = 'last_used_box_id';

  static final LocationMemoryService _instance =
      LocationMemoryService._internal();
  factory LocationMemoryService() => _instance;
  LocationMemoryService._internal();

  Future<void> saveLocation({String? cabinetId, String? boxId}) async {
    final prefs = await SharedPreferences.getInstance();

    if (cabinetId != null && cabinetId.isNotEmpty) {
      await prefs.setString(_kCabinetKey, cabinetId);
    } else {
      await prefs.remove(_kCabinetKey);
    }

    if (boxId != null && boxId.isNotEmpty) {
      await prefs.setString(_kBoxKey, boxId);
    } else {
      await prefs.remove(_kBoxKey);
    }
  }

  Future<String?> getLastCabinetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCabinetKey);
  }

  Future<String?> getLastBoxId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBoxKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCabinetKey);
    await prefs.remove(_kBoxKey);
  }
}