// lib/models/cabinet_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CabinetModel {
  final String? id;
  final String name;
  final String? location;
  final String? description;
  final String? icon;
  final String? color;
  final String? photoUrl;
  final bool isFavorite;
  final int itemCount;
  final int boxCount;
  
  // ✅ NEW: Sharing fields
  final List<String> sharedWith;
  final Map<String, String> permissions; // userId -> 'view' | 'edit' | 'admin'
  
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  const CabinetModel({
    this.id,
    required this.name,
    this.location,
    this.description,
    this.icon,
    this.color,
    this.photoUrl,
    this.isFavorite = false,
    this.itemCount = 0,
    this.boxCount = 0,
    this.sharedWith = const [],
    this.permissions = const {},
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  factory CabinetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CabinetModel(
      id: doc.id,
      name: data['name'] ?? '',
      location: data['location'],
      description: data['description'],
      icon: data['icon'],
      color: data['color'],
      photoUrl: data['photoUrl'],
      isFavorite: data['isFavorite'] ?? false,
      itemCount: data['itemCount'] ?? 0,
      boxCount: data['boxCount'] ?? 0,
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
      permissions: Map<String, String>.from(data['permissions'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'description': description,
      'icon': icon,
      'color': color,
      'photoUrl': photoUrl,
      'isFavorite': isFavorite,
      'itemCount': itemCount,
      'boxCount': boxCount,
      'sharedWith': sharedWith,
      'permissions': permissions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'userId': userId,
    };
  }

  CabinetModel copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    String? icon,
    String? color,
    String? photoUrl,
    bool? isFavorite,
    int? itemCount,
    int? boxCount,
    List<String>? sharedWith,
    Map<String, String>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  }) {
    return CabinetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      photoUrl: photoUrl ?? this.photoUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      itemCount: itemCount ?? this.itemCount,
      boxCount: boxCount ?? this.boxCount,
      sharedWith: sharedWith ?? this.sharedWith,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }

  // ── Computed Properties ──────────────────────────────
  bool get hasItems => itemCount > 0;
  bool get hasBoxes => boxCount > 0;
  bool get isEmpty => itemCount == 0;

  String get itemText => itemCount == 1 ? '1 item' : '$itemCount items';
  String get boxText => boxCount == 1 ? '1 box' : '$boxCount boxes';

  // ✅ Check if user has access
  bool hasAccess(String userId) {
    return userId == this.userId || sharedWith.contains(userId);
  }

  // ✅ Get user's permission level
  String getPermission(String userId) {
    if (userId == this.userId) return 'admin';
    return permissions[userId] ?? 'view';
  }

  // ✅ Check if user can edit
  bool canEdit(String userId) {
    final perm = getPermission(userId);
    return perm == 'edit' || perm == 'admin';
  }

  // ✅ Check if user can delete
  bool canDelete(String userId) {
    final perm = getPermission(userId);
    return perm == 'admin';
  }

  // ✅ Get list of users with access
  List<String> getUsersWithAccess() {
    return [userId, ...sharedWith];
  }

  // ✅ Get permission label
  String getPermissionLabel(String userId) {
    final perm = getPermission(userId);
    switch (perm) {
      case 'view': return '👁️ View Only';
      case 'edit': return '✏️ Edit';
      case 'admin': return '👑 Admin';
      default: return 'Unknown';
    }
  }
}