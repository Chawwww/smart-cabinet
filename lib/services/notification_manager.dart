// lib/services/notification_manager.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // ── Create Notification ──────────────────────────────

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? itemId,
    String? doorId,
    String? doorStatus,
    String? cabinetId,
  }) async {
    try {
      final notification = NotificationModel(
        title: title,
        body: body,
        type: type,
        itemId: itemId,
        doorId: doorId,
        doorStatus: doorStatus,
        userId: userId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.notificationsCollection)
          .add(notification.toFirestore());

      // Send push notification if user has FCM token
      await _notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: type,
      );
    } catch (e) {
      print('❌ Failed to create notification: $e');
    }
  }

  // ── Door Event Notifications ─────────────────────────

  Future<void> notifyDoorEvent({
    required String doorId,
    required String doorStatus,
    required String userId,
    String? cabinetId,
  }) async {
    final isOpened = doorStatus == 'opened';
    final doorLabel = doorId == 'upper' ? 'Upper' : 'Lower';

    final title = isOpened
        ? '$doorLabel Door Opened'
        : '$doorLabel Door Closed';
    final body = isOpened
        ? 'The $doorLabel has been opened.'
        : 'The $doorLabel has been closed.';

    await createNotification(
      userId: userId,
      title: title,
      body: body,
      type: 'door_${doorId}_${doorStatus}',
      doorId: doorId,
      doorStatus: doorStatus,
      cabinetId: cabinetId,
    );
  }

  // ── Expiry Notifications ─────────────────────────────

  Future<void> notifyExpiry({
    required String userId,
    required String itemName,
    String? itemId,
  }) async {
    await createNotification(
      userId: userId,
      title: '⏰ Expiry Reminder',
      body: '$itemName is expiring soon! Check your inventory.',
      type: 'expiry',
      itemId: itemId,
    );
  }

  // ── Low Stock Notifications ──────────────────────────

  Future<void> notifyLowStock({
    required String userId,
    required String itemName,
    required int quantity,
    String? itemId,
  }) async {
    await createNotification(
      userId: userId,
      title: '📉 Low Stock Alert',
      body: '$itemName is running low (only $quantity left). Time to restock!',
      type: 'low_stock',
      itemId: itemId,
    );
  }

  // ── Share Cabinet Notifications ──────────────────────

  Future<void> notifyCabinetShared({
    required String userId,
    required String cabinetName,
    required String sharedBy,
    String? cabinetId,
  }) async {
    await createNotification(
      userId: userId,
      title: '📂 Cabinet Shared',
      body: '$sharedBy shared "$cabinetName" with you',
      type: 'share',
      cabinetId: cabinetId,
    );
  }

  // ── Get Expiry Alert Days ──────────────────────────────

  Future<int> getExpiryAlertDays(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('settings')) {
        final settings = data['settings'] as Map<String, dynamic>?;
        return settings?['expiryAlertDays'] as int? ?? 7;
      }
    }
    return 7;
  }

  // ── Set Expiry Alert Days ──────────────────────────────

  Future<void> setExpiryAlertDays(String userId, int days) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
          'settings.expiryAlertDays': days,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // ── Check Expiry Reminders ───────────────────────────

  Future<void> checkExpiryReminders() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final alertDays = await getExpiryAlertDays(userId);

    final items = await _firestore
        .collection(AppConstants.itemsCollection)
        .where('userId', isEqualTo: userId)
        .where('expiryDate', isNotEqualTo: null)
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final doc in items.docs) {
      final expiryDate = (doc.data()['expiryDate'] as Timestamp?)?.toDate();
      if (expiryDate == null) continue;

      final daysLeft = expiryDate.difference(today).inDays;

      // Alert if expiring within alert days and not yet expired
      if (daysLeft <= alertDays && daysLeft >= 0) {
        final itemName = doc.data()['name'] ?? 'Item';

        // Check if notification already sent
        final existing = await _firestore
            .collection(AppConstants.notificationsCollection)
            .where('userId', isEqualTo: userId)
            .where('itemId', isEqualTo: doc.id)
            .where('type', isEqualTo: 'expiry')
            .where('createdAt', isGreaterThanOrEqualTo:
                Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
            .limit(1)
            .get();

        if (existing.docs.isEmpty) {
          await notifyExpiry(
            userId: userId,
            itemName: itemName,
            itemId: doc.id,
          );
        }
      }
    }
  }

  // ── Check Low Stock ──────────────────────────────────

  Future<void> checkLowStock() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final items = await _firestore
        .collection(AppConstants.itemsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in items.docs) {
      final quantity = doc.data()['quantity'] ?? 0;
      final threshold = doc.data()['lowStockThreshold'] ?? 5;
      final itemName = doc.data()['name'] ?? 'Item';

      if (quantity > 0 && quantity <= threshold) {
        // Check if notification already sent
        final existing = await _firestore
            .collection(AppConstants.notificationsCollection)
            .where('userId', isEqualTo: userId)
            .where('itemId', isEqualTo: doc.id)
            .where('type', isEqualTo: 'low_stock')
            .where('createdAt', isGreaterThanOrEqualTo:
                Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
            .limit(1)
            .get();

        if (existing.docs.isEmpty) {
          await notifyLowStock(
            userId: userId,
            itemName: itemName,
            quantity: quantity,
            itemId: doc.id,
          );
        }
      }
    }
  }

  // ── Mark Notification as Read ────────────────────────

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Delete Notification ──────────────────────────────

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}