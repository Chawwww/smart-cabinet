import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String? id;
  final String name;
  final String? description;

  final String categoryId;
  final String cabinetId;
  final String boxId;

  final String? icon;
  final String? color;

  final int quantity;
  final int initialQuantity;
  final String unit;
  final int lowStockThreshold;

  final DateTime? expiryDate;
  final DateTime? productionDate;

  final String status;

  final String? brand;
  final String? modelNumber;
  final String? serialNumber;

  final double? purchasePrice;
  final DateTime? purchaseDate;
  final String? purchaseLocation;

  final List<String> imageUrls;
  final List<String> tags;

  final String? note;

  final Map<String, dynamic> customFields;

  final bool isFavorite;

  final String? lastTakenBy;
  final DateTime? lastTakenTime;
  final int takenCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String userId;

  const ItemModel({
    this.id,
    required this.name,
    this.description,
    required this.categoryId,
    required this.cabinetId,
    required this.boxId,
    this.icon,
    this.color,
    this.quantity = 0,
    this.initialQuantity = 0,
    this.unit = "pcs",
    this.lowStockThreshold = 5,
    this.expiryDate,
    this.productionDate,
    this.status = "inside",
    this.brand,
    this.modelNumber,
    this.serialNumber,
    this.purchasePrice,
    this.purchaseDate,
    this.purchaseLocation,
    this.imageUrls = const [],
    this.tags = const [],
    this.note,
    this.customFields = const {},
    this.isFavorite = false,
    this.lastTakenBy,
    this.lastTakenTime,
    this.takenCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ItemModel(
      id: doc.id,
      name: data["name"] ?? "",
      description: data["description"],

      categoryId: data["categoryId"] ?? "",
      cabinetId: data["cabinetId"] ?? "",
      boxId: data["boxId"] ?? "",

      icon: data["icon"],
      color: data["color"],

      quantity: data["quantity"] ?? 0,
      initialQuantity: data["initialQuantity"] ?? 0,

      unit: data["unit"] ?? "pcs",
      lowStockThreshold: data["lowStockThreshold"] ?? 5,

      expiryDate: (data["expiryDate"] as Timestamp?)?.toDate(),
      productionDate: (data["productionDate"] as Timestamp?)?.toDate(),

      status: data["status"] ?? "inside",

      brand: data["brand"],
      modelNumber: data["modelNumber"],
      serialNumber: data["serialNumber"],

      purchasePrice: (data["purchasePrice"] as num?)?.toDouble(),
      purchaseDate: (data["purchaseDate"] as Timestamp?)?.toDate(),
      purchaseLocation: data["purchaseLocation"],

      imageUrls: List<String>.from(data["imageUrls"] ?? []),
      tags: List<String>.from(data["tags"] ?? []),

      note: data["note"],

      customFields:
          Map<String, dynamic>.from(data["customFields"] ?? {}),

      isFavorite: data["isFavorite"] ?? false,

      lastTakenBy: data["lastTakenBy"],

      lastTakenTime:
          (data["lastTakenTime"] as Timestamp?)?.toDate(),

      takenCount: data["takenCount"] ?? 0,

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
      "description": description,

      "categoryId": categoryId,
      "cabinetId": cabinetId,
      "boxId": boxId,

      "icon": icon,
      "color": color,

      "quantity": quantity,
      "initialQuantity": initialQuantity,

      "unit": unit,
      "lowStockThreshold": lowStockThreshold,

      "expiryDate":
          expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,

      "productionDate":
          productionDate != null
              ? Timestamp.fromDate(productionDate!)
              : null,

      "status": status,

      "brand": brand,
      "modelNumber": modelNumber,
      "serialNumber": serialNumber,

      "purchasePrice": purchasePrice,

      "purchaseDate":
          purchaseDate != null
              ? Timestamp.fromDate(purchaseDate!)
              : null,

      "purchaseLocation": purchaseLocation,

      "imageUrls": imageUrls,
      "tags": tags,

      "note": note,

      "customFields": customFields,

      "isFavorite": isFavorite,

      "lastTakenBy": lastTakenBy,

      "lastTakenTime":
          lastTakenTime != null
              ? Timestamp.fromDate(lastTakenTime!)
              : null,

      "takenCount": takenCount,

      "createdAt": Timestamp.fromDate(createdAt),
      "updatedAt": Timestamp.fromDate(updatedAt),

      "userId": userId,
    };
  }

  ItemModel copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    String? cabinetId,
    String? boxId,
    String? icon,
    String? color,
    int? quantity,
    int? initialQuantity,
    String? unit,
    int? lowStockThreshold,
    DateTime? expiryDate,
    DateTime? productionDate,
    String? status,
    String? brand,
    String? modelNumber,
    String? serialNumber,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? purchaseLocation,
    List<String>? imageUrls,
    List<String>? tags,
    String? note,
    Map<String, dynamic>? customFields,
    bool? isFavorite,
    String? lastTakenBy,
    DateTime? lastTakenTime,
    int? takenCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      cabinetId: cabinetId ?? this.cabinetId,
      boxId: boxId ?? this.boxId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      unit: unit ?? this.unit,
      lowStockThreshold:
          lowStockThreshold ?? this.lowStockThreshold,
      expiryDate: expiryDate ?? this.expiryDate,
      productionDate: productionDate ?? this.productionDate,
      status: status ?? this.status,
      brand: brand ?? this.brand,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseLocation:
          purchaseLocation ?? this.purchaseLocation,
      imageUrls: imageUrls ?? this.imageUrls,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      customFields: customFields ?? this.customFields,
      isFavorite: isFavorite ?? this.isFavorite,
      lastTakenBy: lastTakenBy ?? this.lastTakenBy,
      lastTakenTime: lastTakenTime ?? this.lastTakenTime,
      takenCount: takenCount ?? this.takenCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }

  // ==========================
  // Computed Properties
  // ==========================

  bool get isLowStock =>
      quantity <= lowStockThreshold && quantity > 0;

  bool get isOutOfStock => quantity <= 0;

  bool get hasExpiry => expiryDate != null;

  bool get isExpired {
    if (expiryDate == null) return false;

    return expiryDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;

    return expiryDate!
        .difference(DateTime.now())
        .inDays <= 7;
  }

  String get expiryStatus {
    if (expiryDate == null) return "normal";

    if (isExpired) return "expired";

    if (isExpiringSoon) return "expiring_soon";

    return "normal";
  }

  String get daysLeftText {
    if (expiryDate == null) {
      return "No expiry date";
    }

    final daysLeft =
        expiryDate!.difference(DateTime.now()).inDays;

    if (daysLeft < 0) {
      return "Expired";
    }

    if (daysLeft == 0) {
      return "Expires today";
    }

    return "$daysLeft days left";
  }
}