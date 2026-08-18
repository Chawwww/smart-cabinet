// lib/services/firestore_service.dart
import 'dart:async';
import 'dart:developer';
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
    if (dateOfBirth != null)
      updates['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
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

  // ✅ FIXED - Returns both owned AND shared cabinets
  Stream<List<CabinetModel>> getCabinets() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    // Use a broadcast stream controller to combine results
    final controller = StreamController<List<CabinetModel>>.broadcast();

    // Track loaded state
    bool ownedLoaded = false;
    bool sharedLoaded = false;
    List<CabinetModel> ownedCabinets = [];
    List<CabinetModel> sharedCabinets = [];
    StreamSubscription? ownedSubscription;
    StreamSubscription? sharedSubscription;

    void checkAndEmit() {
      if (ownedLoaded && sharedLoaded) {
        // Combine and remove duplicates
        final allCabinets = [...ownedCabinets, ...sharedCabinets];
        final uniqueCabinets = <String, CabinetModel>{};
        for (final cabinet in allCabinets) {
          if (cabinet.id != null) {
            uniqueCabinets[cabinet.id!] = cabinet;
          }
        }

        final result = uniqueCabinets.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        log('🗄️ Cabinets loaded: ${result.length} (${ownedCabinets.length} owned, ${sharedCabinets.length} shared)');
        controller.add(result);
      }
    }

    // Listen to owned cabinets
    ownedSubscription = _firestore
        .collection(AppConstants.cabinetsCollection)
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .listen(
      (snapshot) {
        ownedCabinets = snapshot.docs
            .map((doc) => CabinetModel.fromFirestore(doc))
            .toList();
        ownedLoaded = true;
        checkAndEmit();
      },
      onError: (error) {
        log('Error loading owned cabinets: $error');
        ownedLoaded = true;
        checkAndEmit();
        controller.addError(error);
      },
    );

    // Listen to shared cabinets
    sharedSubscription = _firestore
        .collection(AppConstants.cabinetsCollection)
        .where('sharedWith', arrayContains: _userId)
        .snapshots()
        .listen(
      (snapshot) {
        sharedCabinets = snapshot.docs
            .map((doc) => CabinetModel.fromFirestore(doc))
            .toList();
        sharedLoaded = true;
        checkAndEmit();
      },
      onError: (error) {
        log('Error loading shared cabinets: $error');
        sharedLoaded = true;
        checkAndEmit();
        controller.addError(error);
      },
    );

    controller.onCancel = () async {
      await ownedSubscription?.cancel();
      await sharedSubscription?.cancel();
    };

    return controller.stream;
  }

  // Legacy method - kept for compatibility
  Stream<List<CabinetModel>> getOwnedCabinets() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.cabinetsCollection)
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) {
      final cabinets =
          snapshot.docs.map((doc) => CabinetModel.fromFirestore(doc)).toList();
      cabinets.sort((a, b) => a.name.compareTo(b.name));
      return cabinets;
    });
  }

  Stream<List<CabinetModel>> getSharedCabinets() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.cabinetsCollection)
        .where('sharedWith', arrayContains: _userId)
        .snapshots()
        .map((snapshot) {
      final cabinets =
          snapshot.docs.map((doc) => CabinetModel.fromFirestore(doc)).toList();
      cabinets.sort((a, b) => a.name.compareTo(b.name));
      return cabinets;
    });
  }

  Future<void> addCabinet(CabinetModel cabinet) async {
    final doc = _firestore.collection(AppConstants.cabinetsCollection).doc();

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

  // ✅ FIXED - Returns boxes for owned AND shared cabinets
  Stream<List<BoxModel>> getBoxes() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    final controller = StreamController<List<BoxModel>>.broadcast();
    final boxesById = <String, BoxModel>{};
    final boxSubscriptions = <StreamSubscription>[];
    StreamSubscription? cabinetSubscription;

    void emit() {
      final boxes = boxesById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!controller.isClosed) controller.add(boxes);
    }

    Future<void> watchBoxes(List<String> cabinetIds) async {
      for (final subscription in boxSubscriptions) {
        await subscription.cancel();
      }
      boxSubscriptions.clear();
      boxesById.clear();

      for (var start = 0; start < cabinetIds.length; start += 30) {
        final end =
            (start + 30 < cabinetIds.length) ? start + 30 : cabinetIds.length;
        final ids = cabinetIds.sublist(start, end);
        final subscription = _firestore
            .collection(AppConstants.boxesCollection)
            .where('cabinetId', whereIn: ids)
            .snapshots()
            .listen((snapshot) {
          boxesById.removeWhere((_, box) => ids.contains(box.cabinetId));
          for (final doc in snapshot.docs) {
            boxesById[doc.id] = BoxModel.fromFirestore(doc);
          }
          emit();
        }, onError: controller.addError);
        boxSubscriptions.add(subscription);
      }
      emit();
    }

    controller.onListen = () {
      cabinetSubscription = getCabinets().listen(
        (cabinets) => watchBoxes(
          cabinets.map((cabinet) => cabinet.id).whereType<String>().toList(),
        ),
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      await cabinetSubscription?.cancel();
      for (final subscription in boxSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  // Legacy method - kept for compatibility
  Stream<List<BoxModel>> getOwnedBoxes() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.boxesCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BoxModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addBox(BoxModel box) async {
    final doc = _firestore.collection(AppConstants.boxesCollection).doc();

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

    // Items belong to a cabinet as well as to the user who created them.
    // Loading only by userId hides an owner's items from collaborators and
    // hides collaborator-created items from the owner. Combine the user's own
    // items (including unassigned ones) with every item in an accessible
    // cabinet. Firestore limits whereIn to 30 values, so large accounts are
    // split into chunks.
    final controller = StreamController<List<ItemModel>>.broadcast();
    final ownItems = <String, ItemModel>{};
    final cabinetItems = <String, ItemModel>{};
    StreamSubscription? ownSubscription;
    StreamSubscription? cabinetSubscription;
    final itemSubscriptions = <StreamSubscription>[];

    void emit() {
      final combined = <String, ItemModel>{
        ...ownItems,
        ...cabinetItems,
      }.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!controller.isClosed) controller.add(combined);
    }

    Future<void> watchCabinetItems(List<String> cabinetIds) async {
      for (final subscription in itemSubscriptions) {
        await subscription.cancel();
      }
      itemSubscriptions.clear();
      cabinetItems.clear();

      for (var start = 0; start < cabinetIds.length; start += 30) {
        final end =
            (start + 30 < cabinetIds.length) ? start + 30 : cabinetIds.length;
        final ids = cabinetIds.sublist(start, end);
        final subscription = _firestore
            .collection(AppConstants.itemsCollection)
            .where('cabinetId', whereIn: ids)
            .snapshots()
            .listen((snapshot) {
          // Remove stale results belonging to this query chunk before adding
          // its latest snapshot.
          cabinetItems.removeWhere((_, item) => ids.contains(item.cabinetId));
          for (final doc in snapshot.docs) {
            cabinetItems[doc.id] = ItemModel.fromFirestore(doc);
          }
          emit();
        }, onError: controller.addError);
        itemSubscriptions.add(subscription);
      }
      emit();
    }

    controller.onListen = () {
      ownSubscription = _firestore
          .collection(AppConstants.itemsCollection)
          .where('userId', isEqualTo: _userId)
          .snapshots()
          .listen((snapshot) {
        ownItems
          ..clear()
          ..addEntries(snapshot.docs
              .map((doc) => MapEntry(doc.id, ItemModel.fromFirestore(doc))));
        emit();
      }, onError: controller.addError);

      cabinetSubscription = getCabinets().listen(
        (cabinets) => watchCabinetItems(
          cabinets.map((cabinet) => cabinet.id).whereType<String>().toList(),
        ),
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      await ownSubscription?.cancel();
      await cabinetSubscription?.cancel();
      for (final subscription in itemSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Stream<List<ItemModel>> getItemsByCabinet(String cabinetId) {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.itemsCollection)
        .where('cabinetId', isEqualTo: cabinetId)
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }

  /// Creates stock or increases matching stock. The document id is
  /// deterministic, so concurrent scans cannot produce duplicate documents for
  /// the same item/location.
  Future<String> addItem(ItemModel item) async {
    if (_userId.isEmpty) throw StateError('User is not authenticated.');

    final itemKey = _itemKey(item);
    final doc =
        _firestore.collection(AppConstants.itemsCollection).doc(itemKey);
    int quantityAfter = item.quantity;
    String historyAction = 'create';

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(doc);
      if (existing.exists) {
        final oldQuantity =
            (existing.data()?['quantity'] as num?)?.toInt() ?? 0;
        final newQuantity = oldQuantity + item.quantity;
        quantityAfter = newQuantity;
        historyAction = 'add';
        transaction.update(doc, {
          'quantity': newQuantity,
          'status': newQuantity == 0 ? 'taken' : 'inside',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(
            doc, item.copyWith(id: doc.id, itemKey: itemKey).toFirestore());
      }
    });

    // History must never make stock creation fail. In particular, older
    // Firestore rule sets may not yet grant clients access to item_history.
    await _writeItemHistorySafely(
      itemId: doc.id,
      item: item.copyWith(itemKey: itemKey),
      action: historyAction,
      quantityDelta: item.quantity,
      quantityAfter: quantityAfter,
    );
    return doc.id;
  }

  Future<void> updateItem(ItemModel item) async {
    if (item.id == null) return;

    final itemRef =
        _firestore.collection(AppConstants.itemsCollection).doc(item.id);
    int? quantityDelta;
    int? quantityAfter;
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(itemRef);
      if (!existing.exists) throw StateError('Item no longer exists.');
      final oldQuantity = (existing.data()?['quantity'] as num?)?.toInt() ?? 0;
      transaction.update(itemRef, item.toFirestore());
      if (oldQuantity != item.quantity) {
        quantityDelta = item.quantity - oldQuantity;
        quantityAfter = item.quantity;
      }
    });

    if (quantityDelta != null && quantityAfter != null) {
      await _writeItemHistorySafely(
        itemId: item.id!,
        item: item,
        action: quantityDelta! > 0 ? 'add' : 'remove',
        quantityDelta: quantityDelta!,
        quantityAfter: quantityAfter!,
      );
    }
  }

  Stream<List<Map<String, dynamic>>> getItemHistory({int limit = 200}) {
    if (_userId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(AppConstants.itemHistoryCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('timestamp', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  String _itemKey(ItemModel item) {
    String clean(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    // Include location so identical products stored in different boxes remain
    // independently traceable.
    return [
      _userId,
      clean(item.name),
      clean(item.categoryId),
      clean(item.cabinetId ?? 'unassigned'),
      clean(item.boxId ?? 'unassigned'),
      clean(item.unit),
    ].join('_');
  }

  Map<String, dynamic> _historyData({
    required String itemId,
    required ItemModel item,
    required String action,
    required int quantityDelta,
    required int quantityAfter,
  }) =>
      {
        'itemId': itemId,
        'itemKey': item.itemKey ?? _itemKey(item),
        'itemName': item.name,
        'categoryId': item.categoryId,
        'userId': _userId,
        'action': action,
        'quantity': quantityDelta,
        'quantityAfter': quantityAfter,
        'unit': item.unit,
        'timestamp': FieldValue.serverTimestamp(),
      };

  /// Keeps audit logging best-effort so missing history permissions do not
  /// block the primary inventory operation.
  Future<void> _writeItemHistorySafely({
    required String itemId,
    required ItemModel item,
    required String action,
    required int quantityDelta,
    required int quantityAfter,
  }) async {
    try {
      await _firestore.collection(AppConstants.itemHistoryCollection).add(
            _historyData(
              itemId: itemId,
              item: item,
              action: action,
              quantityDelta: quantityDelta,
              quantityAfter: quantityAfter,
            ),
          );
    } on FirebaseException catch (error) {
      log('Item saved, but audit history was not recorded: ${error.code}');
    }
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
        .snapshots()
        .map((snapshot) {
      final categories =
          snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      categories.sort((a, b) => a.name.compareTo(b.name));
      return categories;
    });
  }

  Future<void> addCategory(CategoryModel category) async {
    final doc = _firestore.collection(AppConstants.categoriesCollection).doc();

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
    await _firestore.collection('door_logs').add(log.toFirestore());
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
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return UserModel.fromMap(
          snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    return null;
  }
}
