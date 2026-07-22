// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cabinet_model.dart';
import '../models/box_model.dart';
import '../models/category_model.dart';
import '../models/item_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../models/door_log_model.dart';
import '../config/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  // ── USERS ─────────────────────────────────────────────

  Stream<UserModel?> getUser(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserModel.fromMap(doc.data()!, doc.id);
          }
          return null;
        });
  }

  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? avatar,
    DateTime? dateOfBirth,
    String? bio,
    List<String>? interests,
    bool? isPublic,
    String? location,
    String? phoneNumber,
    String? website,
    Map<String, dynamic>? settings,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (avatar != null) updates['avatar'] = avatar;
    if (dateOfBirth != null) updates['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    if (bio != null) updates['bio'] = bio;
    if (interests != null) updates['interests'] = interests;
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (location != null) updates['location'] = location;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (website != null) updates['website'] = website;
    if (settings != null) updates['settings'] = settings;

    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update(updates);
  }

  // ── CABINETS ──────────────────────────────────────────

  Stream<List<CabinetModel>> getCabinets() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.cabinetsCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CabinetModel.fromFirestore(doc))
              .toList();
        });
  }

  Stream<List<CabinetModel>> getSharedCabinets() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.cabinetsCollection)
        .where('sharedWith', arrayContains: _userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CabinetModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> addCabinet(CabinetModel cabinet) async {
    final doc = _firestore
        .collection(AppConstants.cabinetsCollection)
        .doc();

    final data = cabinet.copyWith(id: doc.id).toFirestore();
    await doc.set(data);
  }

  Future<void> updateCabinet(CabinetModel cabinet) async {
    if (cabinet.id == null) return;

    await _firestore
        .collection(AppConstants.cabinetsCollection)
        .doc(cabinet.id)
        .update(cabinet.toFirestore());
  }

  Future<void> deleteCabinet(String cabinetId) async {
    await _firestore
        .collection(AppConstants.cabinetsCollection)
        .doc(cabinetId)
        .delete();
  }

  // ── SHARED CABINETS ──────────────────────────────────

  Future<void> shareCabinet({
    required String cabinetId,
    required String sharedWithUserId,
    required String permission,
  }) async {
    await _firestore.collection('shared_cabinets').add({
      'cabinetId': cabinetId,
      'sharedWith': sharedWithUserId,
      'permission': permission,
      'ownerId': _userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update cabinet document
    await _firestore
        .collection(AppConstants.cabinetsCollection)
        .doc(cabinetId)
        .update({
          'sharedWith': FieldValue.arrayUnion([sharedWithUserId]),
          'permissions.${sharedWithUserId}': permission,
        });
  }

  Future<void> revokeShare(String cabinetId, String userId) async {
    await _firestore
        .collection(AppConstants.cabinetsCollection)
        .doc(cabinetId)
        .update({
          'sharedWith': FieldValue.arrayRemove([userId]),
          'permissions.${userId}': FieldValue.delete(),
        });
  }

  // ── BOXES ─────────────────────────────────────────────

  Stream<List<BoxModel>> getBoxes() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.boxesCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BoxModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> addBox(BoxModel box) async {
    final doc = _firestore
        .collection(AppConstants.boxesCollection)
        .doc();

    final data = box.copyWith(id: doc.id).toFirestore();
    await doc.set(data);
  }

  Future<void> updateBox(BoxModel box) async {
    if (box.id == null) return;

    await _firestore
        .collection(AppConstants.boxesCollection)
        .doc(box.id)
        .update(box.toFirestore());
  }

  Future<void> deleteBox(String boxId) async {
    await _firestore
        .collection(AppConstants.boxesCollection)
        .doc(boxId)
        .delete();
  }

  // ── ITEMS ─────────────────────────────────────────────

  Stream<List<ItemModel>> getItems() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.itemsCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ItemModel.fromFirestore(doc))
              .toList();
        });
  }

  Stream<List<ItemModel>> getItemsByCabinet(String cabinetId) {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.itemsCollection)
        .where('userId', isEqualTo: _userId)
        .where('cabinetId', isEqualTo: cabinetId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ItemModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> addItem(ItemModel item) async {
    final doc = _firestore
        .collection(AppConstants.itemsCollection)
        .doc();

    final data = item.copyWith(id: doc.id).toFirestore();
    await doc.set(data);
  }

  Future<void> updateItem(ItemModel item) async {
    if (item.id == null) return;

    await _firestore
        .collection(AppConstants.itemsCollection)
        .doc(item.id)
        .update(item.toFirestore());
  }

  Future<void> deleteItem(String itemId) async {
    await _firestore
        .collection(AppConstants.itemsCollection)
        .doc(itemId)
        .delete();
  }

  // ── CATEGORIES ────────────────────────────────────────

  Stream<List<CategoryModel>> getCategories() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.categoriesCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> addCategory(CategoryModel category) async {
    final doc = _firestore
        .collection(AppConstants.categoriesCollection)
        .doc();

    final data = category.copyWith(id: doc.id).toFirestore();
    await doc.set(data);
  }

  Future<void> updateCategory(CategoryModel category) async {
    if (category.id == null) return;

    await _firestore
        .collection(AppConstants.categoriesCollection)
        .doc(category.id)
        .update(category.toFirestore());
  }

  Future<void> deleteCategory(String categoryId) async {
    await _firestore
        .collection(AppConstants.categoriesCollection)
        .doc(categoryId)
        .delete();
  }

  // ── NOTIFICATIONS ─────────────────────────────────────

  Stream<List<NotificationModel>> getNotifications() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
        });
  }

  Stream<int> getUnreadNotificationCount() {
    if (_userId.isEmpty) {
      return Stream.value(0);
    }

    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: _userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> addNotification(NotificationModel notification) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .add(notification.toFirestore());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead() async {
    final snapshot = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: _userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications() async {
    final snapshot = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: _userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── DOOR LOGS ─────────────────────────────────────────

  Stream<List<DoorLogModel>> getDoorLogs({String? doorId}) {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    var query = _firestore
        .collection('door_logs')
        .where('userId', isEqualTo: _userId)
        .orderBy('timestamp', descending: true)
        .limit(50);

    if (doorId != null) {
      query = query.where('doorId', isEqualTo: doorId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DoorLogModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addDoorLog(DoorLogModel log) async {
    await _firestore
        .collection('door_logs')
        .add(log.toFirestore());
  }

  // ── USER SEARCH ───────────────────────────────────────

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final snapshot = await _firestore
        .collection('users')
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()!, doc.id))
        .toList();
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return UserModel.fromMap(snapshot.docs.first.data()!, snapshot.docs.first.id);
    }
    return null;
  }
}