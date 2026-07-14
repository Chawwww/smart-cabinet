import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import 'notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationManager {
  static final NotificationManager _instance =
      NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final NotificationService _notifService = NotificationService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int defaultExpiryAlertDays = 7;

  // ✅ ADDED — notification_badge.dart calls this but it never existed.
  Stream<int> streamUnreadNotificationCount(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<int> getExpiryAlertDays(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final days = doc.data()?['expiryAlertDays'];
      if (days is int && days > 0) return days;
      return defaultExpiryAlertDays;
    } catch (_) {
      return defaultExpiryAlertDays;
    }
  }

  Future<void> setExpiryAlertDays(String userId, int days) async {
    await _db.collection('users').doc(userId).set(
      {'expiryAlertDays': days},
      SetOptions(merge: true),
    );
  }

  Future<void> onItemSaved(ItemModel item) async {
    if (item.id == null) return;

    final notifId = _stableIdFor(item.id!);

    await _notifService.cancelNotification(notifId);

    if (item.expiryDate == null) return;

    final alertDays = await getExpiryAlertDays(item.userId);

    final warnDate = item.expiryDate!.subtract(Duration(days: alertDays));

    if (warnDate.isAfter(DateTime.now())) {
      await _notifService.scheduleExpiryNotification(
        id: notifId,
        title: '⏰ ${item.name} expiring soon',
        body: 'Expires on ${_fmtDate(item.expiryDate!)}. '
            'Please use or restock soon.',
        scheduledTime: warnDate,
        payload: item.id,
      );
    } else if (item.expiryDate!.isAfter(DateTime.now())) {
      await _notifService.showNotification(
        id: notifId,
        title: '⏰ ${item.name} expiring soon',
        body: 'Expires on ${_fmtDate(item.expiryDate!)}. '
            'Please use or restock soon.',
        payload: item.id,
      );
    }

    await _writeFirestoreNotification(
      item: item,
      type: 'expiry',
      title: '${item.name} is expiring soon',
      body: 'Expires on ${_fmtDate(item.expiryDate!)}',
    );
  }

  Future<void> onLowStock(ItemModel item) async {
    if (!item.isLowStock || item.id == null) return;

    final notifId = _stableIdFor('${item.id}_lowstock');

    await _notifService.showNotification(
      id: notifId,
      title: '📉 ${item.name} low stock',
      body: 'Only ${item.quantity} ${item.unit} left. '
          'Consider restocking.',
      payload: item.id,
    );

    await _writeFirestoreNotification(
      item: item,
      type: 'low_stock',
      title: '${item.name} is low on stock',
      body: 'Only ${item.quantity} ${item.unit} remaining',
    );
  }

  Future<void> onItemDeleted(String itemId) async {
    await _notifService.cancelNotification(_stableIdFor(itemId));
    await _notifService.cancelNotification(
        _stableIdFor('${itemId}_lowstock'));
  }

  Future<void> handleFCMNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      final itemId = data['itemId'];
      final type = data['type'] ?? 'general';

      String title = message.notification?.title ?? data['title'] ?? 'New Notification';
      String body = message.notification?.body ?? data['body'] ?? '';
      String? itemName = data['itemName'];

      if (itemName != null && itemName.isNotEmpty) {
        if (type == 'expiry') {
          title = '⏰ $itemName is expiring soon';
          body = body.isNotEmpty ? body : 'Please use or restock soon.';
        } else if (type == 'low_stock') {
          title = '📉 $itemName is low on stock';
          body = body.isNotEmpty ? body : 'Consider restocking.';
        }
      }

      final notifId = itemId != null
          ? _stableIdFor(itemId)
          : DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifService.showNotification(
        id: notifId,
        title: title,
        body: body,
        payload: itemId,
      );

      if (itemId != null && itemName != null) {
        await _db.collection('notifications').add({
          'userId': data['userId'],
          'itemId': itemId,
          'type': type,
          'title': title,
          'body': body,
          'isRead': false,
          'createdAt': Timestamp.now(),
          'source': 'fcm',
        });
      }

      debugPrint('✅ FCM notification handled: $title');
    } catch (e) {
      debugPrint('❌ Failed to handle FCM notification: $e');
    }
  }

  Future<void> _writeFirestoreNotification({
    required ItemModel item,
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId':    item.userId,
        'itemId':    item.id,
        'type':      type,
        'title':     title,
        'body':      body,
        'isRead':    false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      // Non-fatal
    }
  }

  int _stableIdFor(String id) => id.hashCode & 0x7FFFFFFF;

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}