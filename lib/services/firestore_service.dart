// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/item_model.dart';
import '../models/category_model.dart';
import '../models/cabinet_model.dart';
import '../models/box_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in.");
    }
    return user.uid;
  }

  // ════════════════════════════════════════════════════════
  // ITEM CRUD
  // ════════════════════════════════════════════════════════

  Future<String> addItem(ItemModel item) async {
    final docRef = _firestore.collection('items').doc();
    final itemWithId = item.copyWith(
      id: docRef.id,
      userId: userId,
    );
    await docRef.set(itemWithId.toFirestore());
    return docRef.id;
  }

  Future<void> updateItem(ItemModel item) async {
    if (item.id == null) {
      throw Exception("Item ID is null.");
    }
    await _firestore
        .collection('items')
        .doc(item.id)
        .update(item.toFirestore());
  }

  Future<void> deleteItem(String itemId) async {
    await _firestore
        .collection('items')
        .doc(itemId)
        .delete();
  }

  Stream<List<ItemModel>> getItems() {
    return _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ItemModel.fromFirestore)
              .toList(),
        );
  }

  Future<ItemModel?> findItemByName(String itemName) async {
    final snapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .where('name', isEqualTo: itemName)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }
    return ItemModel.fromFirestore(snapshot.docs.first);
  }

  Stream<List<ItemModel>> getItemsByBox(String boxId) {
    return _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .where('boxId', isEqualTo: boxId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ItemModel.fromFirestore)
              .toList(),
        );
  }

  Stream<List<ItemModel>> getItemsByCabinet(String cabinetId) {
    return _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .where('cabinetId', isEqualTo: cabinetId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ItemModel.fromFirestore)
              .toList(),
        );
  }

  // ════════════════════════════════════════════════════════
  // CATEGORY CRUD
  // ════════════════════════════════════════════════════════

  Future<String> addCategory(CategoryModel category) async {
    final docRef = _firestore.collection('categories').doc();
    final categoryWithId = category.copyWith(
      id: docRef.id,
      userId: userId,
    );
    await docRef.set(categoryWithId.toFirestore());
    return docRef.id;
  }

  Future<void> updateCategory(CategoryModel category) async {
    if (category.id == null) {
      throw Exception("Category ID is null.");
    }
    await _firestore
        .collection('categories')
        .doc(category.id)
        .update(category.toFirestore());
  }

  Future<void> deleteCategory(String categoryId) async {
    final batch = _firestore.batch();

    final items = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .where('categoryId', isEqualTo: categoryId)
        .get();

    for (final item in items.docs) {
      batch.delete(item.reference);
    }

    batch.delete(
      _firestore.collection('categories').doc(categoryId),
    );

    await batch.commit();
  }

  Stream<List<CategoryModel>> getCategories() {
    return _firestore
        .collection('categories')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CategoryModel.fromFirestore)
              .toList(),
        );
  }

  // ════════════════════════════════════════════════════════
  // CABINET CRUD
  // ════════════════════════════════════════════════════════

  Future<String> addCabinet(CabinetModel cabinet) async {
    final docRef = _firestore.collection('cabinets').doc();
    final cabinetWithId = cabinet.copyWith(
      id: docRef.id,
      userId: userId,
    );
    await docRef.set(cabinetWithId.toFirestore());
    return docRef.id;
  }

  Future<void> updateCabinet(CabinetModel cabinet) async {
    if (cabinet.id == null) {
      throw Exception("Cabinet ID is null.");
    }
    await _firestore
        .collection('cabinets')
        .doc(cabinet.id)
        .update(cabinet.toFirestore());
  }

  Future<void> deleteCabinet(String cabinetId) async {
    final batch = _firestore.batch();

    final boxes = await _firestore
        .collection('boxes')
        .where('userId', isEqualTo: userId)
        .where('cabinetId', isEqualTo: cabinetId)
        .get();

    for (final boxDoc in boxes.docs) {
      final items = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .where('boxId', isEqualTo: boxDoc.id)
          .get();

      for (final item in items.docs) {
        batch.delete(item.reference);
      }
      batch.delete(boxDoc.reference);
    }

    batch.delete(
      _firestore.collection('cabinets').doc(cabinetId),
    );

    await batch.commit();
  }

  Stream<List<CabinetModel>> getCabinets() {
    return _firestore
        .collection('cabinets')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CabinetModel.fromFirestore)
              .toList(),
        );
  }

  // ════════════════════════════════════════════════════════
  // BOX CRUD
  // ════════════════════════════════════════════════════════

  Future<String> addBox(BoxModel box) async {
    final docRef = _firestore.collection('boxes').doc();
    final boxWithId = box.copyWith(
      id: docRef.id,
      userId: userId,
    );
    await docRef.set(boxWithId.toFirestore());
    return docRef.id;
  }

  Future<void> updateBox(BoxModel box) async {
    if (box.id == null) {
      throw Exception("Box ID is null.");
    }
    await _firestore
        .collection('boxes')
        .doc(box.id)
        .update(box.toFirestore());
  }

  Future<void> deleteBox(String boxId) async {
    final batch = _firestore.batch();

    final items = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .where('boxId', isEqualTo: boxId)
        .get();

    for (final item in items.docs) {
      batch.delete(item.reference);
    }

    batch.delete(
      _firestore.collection('boxes').doc(boxId),
    );

    await batch.commit();
  }

  Stream<List<BoxModel>> getBoxes() {
    return _firestore
        .collection('boxes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BoxModel.fromFirestore)
              .toList(),
        );
  }

  Stream<List<BoxModel>> getBoxesByCabinet(String cabinetId) {
    return _firestore
        .collection('boxes')
        .where('userId', isEqualTo: userId)
        .where('cabinetId', isEqualTo: cabinetId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BoxModel.fromFirestore)
              .toList(),
        );
  }

  // ════════════════════════════════════════════════════════
  // DASHBOARD STATISTICS
  // ════════════════════════════════════════════════════════

  Future<int> getTotalItemsCount() async {
    final snapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> getTotalCabinetsCount() async {
    final snapshot = await _firestore
        .collection('cabinets')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> getTotalCategoriesCount() async {
    final snapshot = await _firestore
        .collection('categories')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }
}