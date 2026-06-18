import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String? id;

  final String name;
  final String icon;
  final String color;

  final int itemCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String userId;

  const CategoryModel({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.itemCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  factory CategoryModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return CategoryModel(
      id: doc.id,

      name: data["name"] ?? "",

      icon: data["icon"] ?? "📦",

      color: data["color"] ?? "#DDA0DD",

      itemCount: data["itemCount"] ?? 0,

      createdAt:
          (data["createdAt"] as Timestamp?)?.toDate() ??
              DateTime.now(),

      updatedAt:
          (data["updatedAt"] as Timestamp?)?.toDate() ??
              DateTime.now(),

      userId: data["userId"] ?? "",
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "name": name,

      "icon": icon,

      "color": color,

      "itemCount": itemCount,

      "createdAt": Timestamp.fromDate(createdAt),

      "updatedAt": Timestamp.fromDate(updatedAt),

      "userId": userId,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    int? itemCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  }) {
    return CategoryModel(
      id: id ?? this.id,

      name: name ?? this.name,

      icon: icon ?? this.icon,

      color: color ?? this.color,

      itemCount: itemCount ?? this.itemCount,

      createdAt: createdAt ?? this.createdAt,

      updatedAt: updatedAt ?? this.updatedAt,

      userId: userId ?? this.userId,
    );
  }

  // ==========================
  // Computed Properties
  // ==========================

  bool get isEmpty => itemCount == 0;

  bool get hasItems => itemCount > 0;
}