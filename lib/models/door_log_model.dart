// lib/models/door_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DoorLogModel {
  final String? id;
  final String doorId;      // "upper" or "lower"
  final String status;      // "opened" or "closed"
  final DateTime timestamp;
  final String userId;
  final String? cabinetId;
  final String? deviceId;

  const DoorLogModel({
    this.id,
    required this.doorId,
    required this.status,
    required this.timestamp,
    required this.userId,
    this.cabinetId,
    this.deviceId,
  });

  factory DoorLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DoorLogModel(
      id: doc.id,
      doorId: data['doorId'] ?? '',
      status: data['status'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] ?? '',
      cabinetId: data['cabinetId'],
      deviceId: data['deviceId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'doorId': doorId,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'cabinetId': cabinetId,
      'deviceId': deviceId,
    };
  }

  DoorLogModel copyWith({
    String? id,
    String? doorId,
    String? status,
    DateTime? timestamp,
    String? userId,
    String? cabinetId,
    String? deviceId,
  }) {
    return DoorLogModel(
      id: id ?? this.id,
      doorId: doorId ?? this.doorId,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      cabinetId: cabinetId ?? this.cabinetId,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  // ── Computed Properties ──
  bool get isOpened => status.toLowerCase() == 'opened';
  bool get isClosed => status.toLowerCase() == 'closed';
  bool get isUpper => doorId.toLowerCase() == 'upper';
  bool get isLower => doorId.toLowerCase() == 'lower';

  String get doorLabel => isUpper ? 'Upper Door' : 'Lower Door';
  String get statusLabel => isOpened ? 'Opened' : 'Closed';
  String get statusEmoji => isOpened ? '🔓' : '🔒';
  String get doorEmoji => isUpper ? '🔝' : '🔽';

  String get summary => '$doorEmoji $doorLabel $statusLabel';
}