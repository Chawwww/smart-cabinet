import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;

  final String title;
  final String body;

  /// expiry, low_stock, door_open, reminder
  final String type;

  final String? itemId;

  final bool isRead;

  final DateTime createdAt;

  final String userId;

  const NotificationModel({
    this.id,
    required this.title,
    required this.body,
    required this.type,
    this.itemId,
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

      isRead: isRead ?? this.isRead,

      createdAt: createdAt ?? this.createdAt,

      userId: userId ?? this.userId,
    );
  }

  // ========================
  // Helper Getters
  // ========================

  bool get isExpiry =>
      type == 'expiry';

  bool get isLowStock =>
      type == 'low_stock';

  bool get isDoorOpen =>
      type == 'door_open';

  bool get isReminder =>
      type == 'reminder';

  bool get unread =>
      !isRead;

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

    return '${difference.inDays} days ago';
  }
}