// lib/services/door_notification_bridge.dart
//
// Connects IoTService's BLE door-sensor events to NotificationManager so
// a real system notification fires whenever a door opens/closes — not
// just a SnackBar that only shows while SmartCabinetControlScreen happens
// to be the visible screen.
//
// Call DoorNotificationBridge().start() ONCE, at app startup (after the
// user is logged in, since notifyDoorEvent needs a userId) — NOT inside
// a screen's initState(), so it keeps working no matter which screen the
// user is on, or if the app is backgrounded (as long as the BLE
// connection itself is still alive — see the Android/iOS background BLE
// setup notes below).

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'iot_service.dart';
import 'notification_manager.dart';

class DoorNotificationBridge {
  static final DoorNotificationBridge _instance =
      DoorNotificationBridge._internal();
  factory DoorNotificationBridge() => _instance;
  DoorNotificationBridge._internal();

  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    debugPrint('🔔 DoorNotificationBridge starting...');

    _sub = IoTService().doorEvents.listen((event) async {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          debugPrint('⚠️ DoorNotificationBridge: No user logged in, skipping notification');
          return;
        }

        final doorId = event['door'] as String? ?? '';
        final isOpen = event['isOpen'] as bool? ?? false;

        if (doorId.isEmpty) {
          debugPrint('⚠️ DoorNotificationBridge: Empty doorId, skipping');
          return;
        }

        debugPrint('🚪 DoorNotificationBridge: $doorId door ${isOpen ? "opened" : "closed"}');

        await NotificationManager().notifyDoorEvent(
          doorId: doorId,                    // "upper" or "lower"
          doorStatus: isOpen ? 'opened' : 'closed',
          userId: userId,
        );
      } catch (e) {
        debugPrint('❌ DoorNotificationBridge error: $e');
      }
    }, onError: (error) {
      debugPrint('❌ DoorNotificationBridge stream error: $error');
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    debugPrint('🔕 DoorNotificationBridge stopped');
  }
}