import 'package:cloud_firestore/cloud_firestore.dart';

class BoxModel {
  final String? id;

  final String name;
  final String? description;

  final String cabinetId;

  final String type;

  final String? icon;
  final String? color;

  final int? capacity;

  // ✅ ADDED — which physical smart-cabinet door this box sits behind,
  // if any. Matches AppConstants.doorUpper / AppConstants.doorLower.
  // Most boxes (plain shelves/drawers with no actuator) leave this null.
  final String? doorId;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String userId;

  const BoxModel({
    this.id,
    required this.name,
    this.description,
    required this.cabinetId,
    this.type = 'Drawer',
    this.icon,
    this.color,
    this.capacity,
    this.doorId, // ✅ ADDED
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  factory BoxModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return BoxModel(
      id: doc.id,

      name: data['name'] ?? '',

      description: data['description'],

      cabinetId: data['cabinetId'] ?? '',

      type: data['type'] ?? 'Drawer',

      icon: data['icon'],

      color: data['color'],

      capacity: data['capacity'],

      doorId: data['doorId'], // ✅ ADDED

      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),

      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),

      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,

      'description': description,

      'cabinetId': cabinetId,

      'type': type,

      'icon': icon,

      'color': color,

      'capacity': capacity,

      'doorId': doorId, // ✅ ADDED

      'createdAt': Timestamp.fromDate(createdAt),

      'updatedAt': Timestamp.fromDate(updatedAt),

      'userId': userId,
    };
  }

  BoxModel copyWith({
    String? id,
    String? name,
    String? description,
    String? cabinetId,
    String? type,
    String? icon,
    String? color,
    int? capacity,
    String? doorId,          // ✅ ADDED
    bool clearDoorId = false, // ✅ ADDED — explicit way to null it out
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  }) {
    return BoxModel(
      id: id ?? this.id,

      name: name ?? this.name,

      description: description ?? this.description,

      cabinetId: cabinetId ?? this.cabinetId,

      type: type ?? this.type,

      icon: icon ?? this.icon,

      color: color ?? this.color,

      capacity: capacity ?? this.capacity,

      doorId: clearDoorId ? null : (doorId ?? this.doorId), // ✅ ADDED

      createdAt: createdAt ?? this.createdAt,

      updatedAt: updatedAt ?? this.updatedAt,

      userId: userId ?? this.userId,
    );
  }

  // ==========================
  // Computed Properties
  // ==========================

  bool get hasCapacity => capacity != null;

  bool get isDrawer =>
      type.toLowerCase() == 'drawer';

  bool get isShelf =>
      type.toLowerCase() == 'shelf';

  bool get isContainer =>
      type.toLowerCase() == 'container';

  // ✅ ADDED — whether this box is actually wired to a real door/LED
  bool get hasSmartDoor => doorId != null && doorId!.isNotEmpty;

  String get displayCapacity {
    if (capacity == null) {
      return 'Unlimited';
    }

    return '$capacity items';
  }
}