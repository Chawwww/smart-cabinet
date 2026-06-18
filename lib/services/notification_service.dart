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

  //-------------------------------------------------------
  // Initialize
  //-------------------------------------------------------

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse:
          _onNotificationTap,
    );

    await requestPermissions();

    FirebaseMessaging.onMessage.listen(
      showLocalNotification,
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        debugPrint(
          'Notification opened: ${message.data}',
        );
      },
    );
  }

  //-------------------------------------------------------
  // Notification tap
  //-------------------------------------------------------

  void _onNotificationTap(
    NotificationResponse response,
  ) {
    debugPrint(
      'Notification tapped: ${response.payload}',
    );
  }

  //-------------------------------------------------------
  // Request permissions
  //-------------------------------------------------------

  Future<void> requestPermissions() async {
    await Permission.notification.request();

    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  //-------------------------------------------------------
  // Show notification from FCM
  //-------------------------------------------------------

  Future<void> showLocalNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;

    if (notification == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'smart_cabinet_channel',
      'Smart Cabinet Notifications',
      channelDescription:
          'Notifications for cabinet items',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(
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
  }

  //-------------------------------------------------------
  // Manual notification
  //-------------------------------------------------------

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails();

    const NotificationDetails details =
        NotificationDetails(
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
    final tz.TZDateTime scheduledDate =
        tz.TZDateTime.from(
      scheduledTime,
      tz.local,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Notifications',
      channelDescription:
          'Notifications for item expiry',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails();

    const NotificationDetails details =
        NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  //-------------------------------------------------------
  // Cancel notification
  //-------------------------------------------------------

  Future<void> cancelNotification(
    int id,
  ) async {
    await _localNotifications.cancel(
      id: id,
    );
  }

  //-------------------------------------------------------
  // Cancel all notifications
  //-------------------------------------------------------

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  //-------------------------------------------------------
  // Get FCM token
  //-------------------------------------------------------

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  //-------------------------------------------------------
  // Subscribe topic
  //-------------------------------------------------------

  Future<void> subscribeToTopic(
    String topic,
  ) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(
    String topic,
  ) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}