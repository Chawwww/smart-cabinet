import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;

  final String title;
  final String body;

  /// expiry, low_stock, door_open, reminder, door_upper_opened, door_lower_opened, door_upper_closed, door_lower_closed
  final String type;

  final String? itemId;

  // ── NEW: Door-specific fields ──
  final String? doorId;      // "upper" or "lower"
  final String? doorStatus;  // "opened" or "closed"

  final bool isRead;

  final DateTime createdAt;

  final String userId;

  const NotificationModel({
    this.id,
    required this.title,
    required this.body,
    required this.type,
    this.itemId,
    this.doorId,
    this.doorStatus,
    this.isRead = false,
    required this.createdAt,
    required this.userId,
  });

  factory NotificationModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      itemId: data['itemId'],
      doorId: data['doorId'],
      doorStatus: data['doorStatus'],
      isRead: data['isRead'] ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'itemId': itemId,
      'doorId': doorId,
      'doorStatus': doorStatus,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? itemId,
    String? doorId,
    String? doorStatus,
    bool? isRead,
    DateTime? createdAt,
    String? userId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      doorId: doorId ?? this.doorId,
      doorStatus: doorStatus ?? this.doorStatus,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  // ========================
  // Helper Getters
  // ========================

  bool get isExpiry => type == 'expiry';
  bool get isLowStock => type == 'low_stock';
  bool get isDoorOpen => type == 'door_open';
  bool get isReminder => type == 'reminder';

  // ── NEW: Door event types ──
  bool get isDoorUpperOpened => type == 'door_upper_opened';
  bool get isDoorLowerOpened => type == 'door_lower_opened';
  bool get isDoorUpperClosed => type == 'door_upper_closed';
  bool get isDoorLowerClosed => type == 'door_lower_closed';

  bool get isDoorEvent =>
      isDoorUpperOpened ||
      isDoorLowerOpened ||
      isDoorUpperClosed ||
      isDoorLowerClosed;

  bool get isDoorOpenedEvent =>
      isDoorUpperOpened || isDoorLowerOpened;

  bool get isDoorClosedEvent =>
      isDoorUpperClosed || isDoorLowerClosed;

  bool get unread => !isRead;

  // ── NEW: Door display helpers ──
  String get doorLabel {
    if (doorId == null) return '';
    return doorId == 'upper' ? 'Upper Door' : 'Lower Door';
  }

  String get doorEmoji {
    if (doorId == null) return '🚪';
    return doorId == 'upper' ? '🔝' : '🔽';
  }

  String get doorStatusText {
    if (doorStatus == null) return '';
    return doorStatus == 'opened' ? 'Opened' : 'Closed';
  }

  String get doorStatusEmoji {
    if (doorStatus == null) return '';
    return doorStatus == 'opened' ? '🔓' : '🔒';
  }

  String get doorEventSummary {
    if (!isDoorEvent) return '';
    return '$doorEmoji $doorLabel $doorStatusText';
  }

  // ── NEW: Notification icon based on type ──
  String get iconEmoji {
    if (isExpiry) return '⏰';
    if (isLowStock) return '📉';
    if (isDoorUpperOpened) return '🔝🔓';
    if (isDoorLowerOpened) return '🔽🔓';
    if (isDoorUpperClosed) return '🔝🔒';
    if (isDoorLowerClosed) return '🔽🔒';
    if (isDoorOpen) return '🚪';
    if (isReminder) return '📌';
    return '🔔';
  }

  // ── NEW: Color based on notification type ──
  String get colorHex {
    if (isExpiry) return '#FF5722';       // Deep Orange - Urgent
    if (isLowStock) return '#FF9800';     // Orange - Warning
    if (isDoorUpperOpened) return '#2196F3'; // Blue
    if (isDoorLowerOpened) return '#FF9800'; // Orange
    if (isDoorUpperClosed) return '#4CAF50'; // Green
    if (isDoorLowerClosed) return '#4CAF50'; // Green
    if (isReminder) return '#9C27B0';     // Purple
    return '#607D8B';                     // Blue Grey
  }

  String get timeAgo {
    final difference =
        DateTime.now().difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    }

    final months = (difference.inDays / 30).floor();
    return '$months month${months > 1 ? 's' : ''} ago';
  }

  // ── NEW: Factory methods for common notifications ──

  factory NotificationModel.doorEvent({
    required String doorId,
    required String doorStatus,
    required String userId,
    String? doorLabel,
  }) {
    final isOpened = doorStatus == 'opened';
    final type = 'door_${doorId}_${doorStatus}';
    final doorDisplay = doorLabel ?? (doorId == 'upper' ? 'Upper' : 'Lower');

    return NotificationModel(
      title: isOpened
          ? '$doorDisplay Door Opened'
          : '$doorDisplay Door Closed',
      body: isOpened
          ? 'The $doorDisplay has been opened.'
          : 'The $doorDisplay has been closed.',
      type: type,
      doorId: doorId,
      doorStatus: doorStatus,
      userId: userId,
      createdAt: DateTime.now(),
    );
  }

  factory NotificationModel.expiry({
    required String itemName,
    required String userId,
    String? itemId,
  }) {
    return NotificationModel(
      title: 'Expiry Reminder',
      body: '$itemName is expiring soon! Check your inventory.',
      type: 'expiry',
      itemId: itemId,
      userId: userId,
      createdAt: DateTime.now(),
    );
  }

  factory NotificationModel.lowStock({
    required String itemName,
    required int quantity,
    required String userId,
    String? itemId,
  }) {
    return NotificationModel(
      title: 'Low Stock Alert',
      body: '$itemName is running low (only $quantity left). Time to restock!',
      type: 'low_stock',
      itemId: itemId,
      userId: userId,
      createdAt: DateTime.now(),
    );
  }

  factory NotificationModel.reminder({
    required String title,
    required String body,
    required String userId,
    String? itemId,
  }) {
    return NotificationModel(
      title: title,
      body: body,
      type: 'reminder',
      itemId: itemId,
      userId: userId,
      createdAt: DateTime.now(),
    );
  }
}