// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;

  //-------------------------------------------------------
  // Initialize
  //-------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // ✅ FIX: Use named parameter for initialize
      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await requestPermissions();

      FirebaseMessaging.onMessage.listen(showLocalNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) {
          debugPrint('Notification opened: ${message.data}');
        },
      );

      _initialized = true;
      debugPrint('✅ Notification Service initialized');
    } catch (e) {
      debugPrint('❌ Notification initialization error: $e');
    }
  }

  //-------------------------------------------------------
  // Register FCM Token
  //-------------------------------------------------------

  Future<void> registerFcmToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _db.collection('fcm_tokens').doc(userId).set({
          'token': token,
          'platform': defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ FCM token registered for $userId');
      }
    } catch (e) {
      debugPrint('❌ Failed to register FCM token: $e');
    }

    // Keep the stored token fresh if it ever rotates
    _fcm.onTokenRefresh.listen((newToken) async {
      try {
        await _db.collection('fcm_tokens').doc(userId).set({
          'token': newToken,
          'platform': defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token refreshed for $userId');
      } catch (e) {
        debugPrint('❌ Failed to refresh FCM token: $e');
      }
    });
  }

  //-------------------------------------------------------
  // Unregister FCM Token (on logout)
  //-------------------------------------------------------

  Future<void> unregisterFcmToken(String userId) async {
    try {
      await _db.collection('fcm_tokens').doc(userId).delete();
      debugPrint('✅ FCM token unregistered for $userId');
    } catch (e) {
      debugPrint('❌ Failed to unregister FCM token: $e');
    }
  }

  //-------------------------------------------------------
  // Notification Tap Handler
  //-------------------------------------------------------

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Handle navigation based on payload
    // Example: Navigate to item detail if payload contains itemId
  }

  //-------------------------------------------------------
  // Request Permissions
  //-------------------------------------------------------

  Future<void> requestPermissions() async {
    try {
      // Android 13+ notification permission
      await Permission.notification.request();

      // iOS permissions
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
    }
  }

  //-------------------------------------------------------
  // Show Local Notification (from FCM message)
  //-------------------------------------------------------

  Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'smart_cabinet_channel',
        'Smart Cabinet Notifications',
        channelDescription: 'Notifications for cabinet items',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ✅ FIX: Use named parameters for show
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: notification.title ?? 'Smart Cabinet',
        body: notification.body ?? '',
        notificationDetails: details,
        payload: message.data['itemId'],
      );
    } catch (e) {
      debugPrint('❌ Show local notification error: $e');
    }
  }

  //-------------------------------------------------------
  // Show General Notification
  //-------------------------------------------------------

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'general_channel',
        'General Notifications',
        channelDescription: 'General notifications',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ✅ FIX: Use named parameters for show
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Show notification error: $e');
    }
  }

  //-------------------------------------------------------
  // Schedule Expiry Notification
  //-------------------------------------------------------

  Future<void> scheduleExpiryNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      final tz.TZDateTime scheduledDate =
          tz.TZDateTime.from(scheduledTime, tz.local);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'expiry_channel',
        'Expiry Notifications',
        channelDescription: 'Notifications for item expiry',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ✅ FIX: Use named parameters for zonedSchedule
      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('✅ Scheduled expiry notification: $id');
    } catch (e) {
      debugPrint('❌ Schedule expiry notification error: $e');
    }
  }

  //-------------------------------------------------------
  // Cancel Notifications
  //-------------------------------------------------------

  Future<void> cancelNotification(int id) async {
    try {
      // ✅ FIX: Use named parameter for cancel
      await _localNotifications.cancel(id: id);
      debugPrint('✅ Cancelled notification: $id');
    } catch (e) {
      debugPrint('❌ Cancel notification error: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('✅ Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ Cancel all notifications error: $e');
    }
  }

  //-------------------------------------------------------
  // Get FCM Token
  //-------------------------------------------------------

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('❌ Get FCM token error: $e');
      return null;
    }
  }

  //-------------------------------------------------------
  // Topic Subscription
  //-------------------------------------------------------

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Subscribe to topic error: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Unsubscribe from topic error: $e');
    }
  }

  //-------------------------------------------------------
  // Get Notification Permission Status
  //-------------------------------------------------------

  Future<bool> hasNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Permission status error: $e');
      return false;
    }
  }

  //-------------------------------------------------------
  // Open App Settings
  //-------------------------------------------------------

  Future<void> openNotificationSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('❌ Open app settings error: $e');
    }
  }
}