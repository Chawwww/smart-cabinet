// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String email;
  final String name;
  final String? avatar;
  final bool emailVerified;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    this.id,
    required this.email,
    required this.name,
    this.avatar,
    this.emailVerified = false,
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      avatar: map['avatar'],
      emailVerified: map['emailVerified'] ?? false,
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'avatar': avatar,
      'emailVerified': emailVerified,
      'settings': settings,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatar,
    bool? emailVerified,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      emailVerified: emailVerified ?? this.emailVerified,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Computed Properties ──────────────────────────────
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;
  String get displayName => name.isNotEmpty ? name : email;
  
  bool get darkMode => settings['darkMode'] ?? false;
  bool get notificationsEnabled => settings['notificationsEnabled'] ?? true;
  bool get biometricEnabled => settings['biometricEnabled'] ?? false;
  bool get doorNotifications => settings['doorNotifications'] ?? true;
  String get language => settings['language'] ?? 'en';
}