// lib/providers/notification_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../config/app_constants.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _subscription;

  // ── Getters ──
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get totalCount => _notifications.length;

  List<NotificationModel> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  List<NotificationModel> get doorNotifications =>
      _notifications.where((n) => n.isDoorEvent).toList();

  List<NotificationModel> get expiryNotifications =>
      _notifications.where((n) => n.isExpiry).toList();

  List<NotificationModel> get lowStockNotifications =>
      _notifications.where((n) => n.isLowStock).toList();

  String get userId => _auth.currentUser?.uid ?? '';

  // ── Load Notifications ──
  void loadNotifications() {
    if (_subscription != null) return;
    if (userId.isEmpty) {
      _notifications = [];
      notifyListeners();
      return;
    }

    _setLoading(true);

    _subscription = _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _notifications = snapshot.docs
                .map(NotificationModel.fromFirestore)
                .toList();
            _error = null;
            _setLoading(false);
            debugPrint('🔔 Notifications loaded: ${_notifications.length}');
          },
          onError: (error) {
            _error = error.toString();
            _setLoading(false);
          },
        );
  }

  void reloadNotifications() {
    _subscription?.cancel();
    _subscription = null;
    _notifications = [];
    loadNotifications();
  }

  // ── Clear Data on Logout ──
  void clearData() {
    _subscription?.cancel();
    _subscription = null;
    _notifications = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
    debugPrint('🧹 NotificationProvider data cleared');
  }

  // ── Mark as Read ──
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('❌ Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      for (final notification in _notifications.where((n) => !n.isRead)) {
        if (notification.id != null) {
          final ref = _firestore
              .collection(AppConstants.notificationsCollection)
              .doc(notification.id);
          batch.update(ref, {'isRead': true});
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Failed to mark all as read: $e');
    }
  }

  // ── Delete Notification ──
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('❌ Failed to delete notification: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final batch = _firestore.batch();
      for (final notification in _notifications) {
        if (notification.id != null) {
          batch.delete(
            _firestore
                .collection(AppConstants.notificationsCollection)
                .doc(notification.id),
          );
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Failed to delete all notifications: $e');
    }
  }

  // ── Create Notification ──
  Future<void> createNotification({
    required String title,
    required String body,
    required String type,
    String? itemId,
    String? doorId,
    String? doorStatus,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.notificationsCollection)
          .add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'itemId': itemId,
        'doorId': doorId,
        'doorStatus': doorStatus,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Failed to create notification: $e');
    }
  }

  // ── Door Event Notifications ──
  Future<void> notifyDoorEvent({
    required String doorId,
    required String doorStatus,
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
      title: title,
      body: body,
      type: 'door_${doorId}_${doorStatus}',
      doorId: doorId,
      doorStatus: doorStatus,
    );
  }

  // ── Helpers ──
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}