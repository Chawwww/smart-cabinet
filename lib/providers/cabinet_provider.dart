// lib/providers/cabinet_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../services/firestore_service.dart';

class CabinetProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CabinetModel> _cabinets = [];
  List<BoxModel> _boxes = [];
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription? _cabinetSubscription;
  StreamSubscription? _boxSubscription;

  // ── Getters ──────────────────────────────────────────────
  List<CabinetModel> get cabinets => _cabinets;
  List<BoxModel> get boxes => _boxes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCabinets => _cabinets.length;
  int get totalBoxes => _boxes.length;

  String get userId => _auth.currentUser?.uid ?? '';

  List<CabinetModel> get accessibleCabinets {
    return _cabinets.where((cabinet) => 
      cabinet.hasAccess(userId)
    ).toList();
  }

  List<CabinetModel> get ownedCabinets {
    return _cabinets.where((cabinet) => 
      cabinet.userId == userId
    ).toList();
  }

  List<CabinetModel> get sharedCabinets {
    return _cabinets.where((cabinet) => 
      cabinet.userId != userId && cabinet.hasAccess(userId)
    ).toList();
  }

  // ── Load Cabinets ───────────────────────────────────────
  void loadCabinets() {
    if (_cabinetSubscription != null) return;
    _setLoading(true);

    _cabinetSubscription = _firestoreService.getCabinets().listen(
      (cabinets) {
        _cabinets = cabinets;
        _error = null;
        _setLoading(false);
        debugPrint('🗄️ Cabinets loaded: ${cabinets.length} (${accessibleCabinets.length} accessible)');
      },
      onError: (error) {
        _error = error.toString();
        _setLoading(false);
      },
    );
  }

  // ── Load Boxes ──────────────────────────────────────────
  void loadBoxes() {
    if (_boxSubscription != null) return;

    _boxSubscription = _firestoreService.getBoxes().listen(
      (boxes) {
        _boxes = boxes;
        notifyListeners();
        debugPrint('📦 Boxes loaded: ${boxes.length}');
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  void reloadCabinets() {
    _cabinetSubscription?.cancel();
    _cabinetSubscription = null;
    _cabinets = [];
    loadCabinets();
  }

  void reloadBoxes() {
    _boxSubscription?.cancel();
    _boxSubscription = null;
    _boxes = [];
    loadBoxes();
  }

  // ✅ Clear Data on Logout
  void clearData() {
    _cabinetSubscription?.cancel();
    _cabinetSubscription = null;
    _boxSubscription?.cancel();
    _boxSubscription = null;
    _cabinets = [];
    _boxes = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
    debugPrint('🧹 CabinetProvider data cleared');
  }

  // ── Cabinet CRUD ────────────────────────────────────────
  Future<void> addCabinet(CabinetModel cabinet) async {
    try {
      _setLoading(true);
      await _firestoreService.addCabinet(cabinet);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> updateCabinet(CabinetModel cabinet) async {
    try {
      _setLoading(true);
      await _firestoreService.updateCabinet(cabinet);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> deleteCabinet(String cabinetId) async {
    try {
      _setLoading(true);
      await _firestoreService.deleteCabinet(cabinetId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  // ── Box CRUD ────────────────────────────────────────────
  Future<void> addBox(BoxModel box) async {
    try {
      _setLoading(true);
      await _firestoreService.addBox(box);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> updateBox(BoxModel box) async {
    try {
      _setLoading(true);
      await _firestoreService.updateBox(box);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> deleteBox(String boxId) async {
    try {
      _setLoading(true);
      await _firestoreService.deleteBox(boxId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  // ── Cabinet Sharing ─────────────────────────────────────
  Future<bool> shareCabinet({
    required String cabinetId,
    required String userEmail,
    required String permission,
  }) async {
    try {
      _setLoading(true);
      
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail.trim())
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('User with email "$userEmail" not found');
      }

      final sharedUserId = userSnapshot.docs.first.id;

      if (sharedUserId == userId) {
        throw Exception('You cannot share with yourself');
      }

      final cabinet = getCabinetById(cabinetId);
      if (cabinet == null) throw Exception('Cabinet not found');

      if (cabinet.sharedWith.contains(sharedUserId)) {
        throw Exception('Already shared with this user');
      }

      final updatedCabinet = cabinet.copyWith(
        sharedWith: [...cabinet.sharedWith, sharedUserId],
        permissions: {
          ...cabinet.permissions,
          sharedUserId: permission,
        },
        updatedAt: DateTime.now(),
      );

      await updateCabinet(updatedCabinet);

      await _createNotification(
        userId: sharedUserId,
        title: '📂 Cabinet Shared',
        body: '${_auth.currentUser?.displayName ?? 'Someone'} shared "${cabinet.name}" with you',
        type: 'share',
        cabinetId: cabinetId,
      );

      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> revokeAccess({
    required String cabinetId,
    required String userId,
  }) async {
    try {
      _setLoading(true);

      final cabinet = getCabinetById(cabinetId);
      if (cabinet == null) throw Exception('Cabinet not found');

      final updatedCabinet = cabinet.copyWith(
        sharedWith: cabinet.sharedWith.where((id) => id != userId).toList(),
        permissions: cabinet.permissions..remove(userId),
        updatedAt: DateTime.now(),
      );

      await updateCabinet(updatedCabinet);
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updatePermission({
    required String cabinetId,
    required String userId,
    required String newPermission,
  }) async {
    try {
      _setLoading(true);

      final cabinet = getCabinetById(cabinetId);
      if (cabinet == null) throw Exception('Cabinet not found');

      final updatedCabinet = cabinet.copyWith(
        permissions: {
          ...cabinet.permissions,
          userId: newPermission,
        },
        updatedAt: DateTime.now(),
      );

      await updateCabinet(updatedCabinet);
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCabinetUsers(String cabinetId) async {
    final cabinet = getCabinetById(cabinetId);
    if (cabinet == null) return [];

    final users = <Map<String, dynamic>>[];
    final userIds = [cabinet.userId, ...cabinet.sharedWith];
    
    for (final uid in userIds) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        users.add({
          'id': uid,
          'name': doc.data()?['name'] ?? 'Unknown',
          'email': doc.data()?['email'] ?? '',
          'permission': cabinet.getPermission(uid),
          'isOwner': uid == cabinet.userId,
        });
      }
    }
    
    return users;
  }

  // ── Find Cabinet ────────────────────────────────────────
  CabinetModel? getCabinetById(String id) {
    try {
      return _cabinets.firstWhere((cabinet) => cabinet.id == id);
    } catch (_) {
      return null;
    }
  }

  BoxModel? getBoxById(String id) {
    try {
      return _boxes.firstWhere((box) => box.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BoxModel> getBoxesForCabinet(String cabinetId) {
    return _boxes.where((box) => box.cabinetId == cabinetId).toList();
  }

  List<CabinetModel> searchCabinets(String keyword) {
    if (keyword.isEmpty) return accessibleCabinets;
    final query = keyword.toLowerCase();
    return accessibleCabinets.where(
      (cabinet) {
        return cabinet.name.toLowerCase().contains(query) ||
            cabinet.location?.toLowerCase().contains(query) == true;
      },
    ).toList();
  }

  List<BoxModel> searchBoxes(String keyword) {
    if (keyword.isEmpty) return _boxes;
    final query = keyword.toLowerCase();
    return _boxes.where(
      (box) {
        return box.name.toLowerCase().contains(query) ||
            box.description?.toLowerCase().contains(query) == true;
      },
    ).toList();
  }

  // ── Helpers ─────────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? cabinetId,
    String? itemId,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'cabinetId': cabinetId,
      'itemId': itemId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _cabinetSubscription?.cancel();
    _boxSubscription?.cancel();
    super.dispose();
  }
}