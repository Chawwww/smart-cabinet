import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADDED for token storage
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ✅ ADDED: was missing — registerFcmToken/unregisterFcmToken reference
  // this but it was never declared, causing "getter '_db' isn't defined".
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //-------------------------------------------------------
  // Initialize
  //-------------------------------------------------------

  Future<void> initialize() async {
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
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  //-------------------------------------------------------
  // ✅ ADDED: Register / refresh this device's FCM token
  // Call this once after the user logs in (e.g. in your
  // AuthProvider right after sign-in succeeds), so Cloud
  // Functions know which device to push door/expiry alerts to.
  //-------------------------------------------------------

  Future<void> registerFcmToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _db.collection('fcm_tokens').doc(userId).set({
          'token': token,
          'platform': defaultTargetPlatform.name,
          'updatedAt': Timestamp.now(),
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
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token refreshed for $userId');
      } catch (e) {
        debugPrint('❌ Failed to refresh FCM token: $e');
      }
    });
  }

  // ✅ ADDED: Call on logout so a shared/borrowed device doesn't
  // keep receiving another user's push notifications.
  Future<void> unregisterFcmToken(String userId) async {
    try {
      await _db.collection('fcm_tokens').doc(userId).delete();
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  //-------------------------------------------------------
  // Request permissions
  //-------------------------------------------------------

  Future<void> requestPermissions() async {
    try {
      await Permission.notification.request();
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

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

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: message.data['itemId'],
      );
    } catch (e) {
      debugPrint('Show local notification error: $e');
    }
  }

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

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }

  //-------------------------------------------------------
  // Schedule expiry notification
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

      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Schedule expiry notification error: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id: id);
    } catch (e) {
      debugPrint('Cancel notification error: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Cancel all notifications error: $e');
    }
  }

  //-------------------------------------------------------
  // Get FCM token
  //-------------------------------------------------------

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Get FCM token error: $e');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('Subscribe to topic error: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('Unsubscribe from topic error: $e');
    }
  }
}