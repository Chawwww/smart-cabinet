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
  
  // Profile fields
  final DateTime? dateOfBirth;
  final String? bio;
  final List<String> interests;
  final bool isPublic;
  final String? location;
  final String? phoneNumber;
  final String? website;

  const UserModel({
    this.id,
    required this.email,
    required this.name,
    this.avatar,
    this.emailVerified = false,
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
    this.dateOfBirth,
    this.bio,
    this.interests = const [],
    this.isPublic = false,
    this.location,
    this.phoneNumber,
    this.website,
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
      dateOfBirth: (map['dateOfBirth'] as Timestamp?)?.toDate(),
      bio: map['bio'],
      interests: List<String>.from(map['interests'] ?? []),
      isPublic: map['isPublic'] ?? false,
      location: map['location'],
      phoneNumber: map['phoneNumber'],
      website: map['website'],
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
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'bio': bio,
      'interests': interests,
      'isPublic': isPublic,
      'location': location,
      'phoneNumber': phoneNumber,
      'website': website,
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
    DateTime? dateOfBirth,
    String? bio,
    List<String>? interests,
    bool? isPublic,
    String? location,
    String? phoneNumber,
    String? website,
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      isPublic: isPublic ?? this.isPublic,
      location: location ?? this.location,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
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
  
  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
  
  int get age {
    if (dateOfBirth == null) return 0;
    final today = DateTime.now();
    int age = today.year - dateOfBirth!.year;
    if (today.month < dateOfBirth!.month || 
        (today.month == dateOfBirth!.month && today.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
  
  String get formattedDateOfBirth {
    if (dateOfBirth == null) return 'Not set';
    return '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}';
  }
}