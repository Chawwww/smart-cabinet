// lib/providers/item_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_model.dart';
import '../services/firestore_service.dart';

class ItemProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ItemModel> _items = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _itemsSubscription;

  // ── Getters ──────────────────────────────────────────────
  List<ItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalItems => _items.length;

  String get userId => _auth.currentUser?.uid ?? '';

  List<ItemModel> get favoriteItems =>
      _items.where((i) => i.isFavorite).toList();

  List<ItemModel> get expiredItems =>
      _items.where((i) => i.isExpired).toList();

  List<ItemModel> get expiringSoonItems =>
      _items.where((i) => i.isExpiringSoon && !i.isExpired).toList();

  List<ItemModel> get lowStockItems =>
      _items.where((i) => i.isLowStock && !i.isOutOfStock).toList();

  List<ItemModel> get outOfStockItems =>
      _items.where((i) => i.isOutOfStock).toList();

  // ── Load Items ──────────────────────────────────────────
  void loadItems() {
    if (_itemsSubscription != null) return;
    _setLoading(true);

    _itemsSubscription = _firestoreService.getItems().listen(
      (items) {
        _items = items;
        _error = null;
        _setLoading(false);
        debugPrint('📦 Items loaded: ${items.length}');
      },
      onError: (e) {
        _error = e.toString();
        _setLoading(false);
      },
    );
  }

  void reloadItems() {
    _itemsSubscription?.cancel();
    _itemsSubscription = null;
    _items = [];
    loadItems();
  }

  // ✅ Clear Data on Logout
  void clearData() {
    _itemsSubscription?.cancel();
    _itemsSubscription = null;
    _items = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
    debugPrint('🧹 ItemProvider data cleared');
  }

  // ── Add Item ────────────────────────────────────────────
  Future<bool> addItem(ItemModel item) async {
    try {
      await _firestoreService.addItem(item);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Update Item ─────────────────────────────────────────
  Future<bool> updateItem(ItemModel item) async {
    try {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _items[idx] = item;
        notifyListeners();
      }
      await _firestoreService.updateItem(item);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      reloadItems();
      return false;
    }
  }

  // ── Delete Item ─────────────────────────────────────────
  Future<bool> deleteItem(String itemId) async {
    try {
      _items.removeWhere((i) => i.id == itemId);
      notifyListeners();
      await _firestoreService.deleteItem(itemId);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      reloadItems();
      return false;
    }
  }

  // ── Toggle Favourite ────────────────────────────────────
  Future<void> toggleFavorite(ItemModel item) async {
    if (item.id == null) return;
    await updateItem(item.copyWith(
      isFavorite: !item.isFavorite,
      updatedAt: DateTime.now(),
    ));
  }

  // ── Record Withdrawal ───────────────────────────────────
  Future<bool> recordWithdrawal({
    required ItemModel item,
    required int qty,
    required String takenBy,
    String? note,
  }) async {
    if (qty <= 0 || qty > item.quantity) return false;

    final now = DateTime.now();
    final record = {
      'qty': qty,
      'by': takenBy,
      'at': now.toIso8601String(),
      'note': note,
    };

    final newQty = item.quantity - qty;
    final updated = item.copyWith(
      quantity: newQty,
      status: newQty == 0 ? 'taken' : 'inside',
      takenCount: item.takenCount + qty,
      lastTakenBy: takenBy,
      lastTakenTime: now,
      withdrawalHistory: [...item.withdrawalHistory, record],
      updatedAt: now,
    );

    return updateItem(updated);
  }

  // ── Return Item ─────────────────────────────────────────
  Future<bool> returnItem(ItemModel item) async {
    final now = DateTime.now();
    final updated = item.copyWith(
      quantity: item.quantity + 1,
      status: 'inside',
      updatedAt: now,
    );
    return updateItem(updated);
  }

  // ── Search ──────────────────────────────────────────────
  List<ItemModel> searchItems(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    return _items.where((item) {
      return item.name.toLowerCase().contains(q) ||
          (item.description?.toLowerCase().contains(q) ?? false) ||
          (item.brand?.toLowerCase().contains(q) ?? false) ||
          (item.note?.toLowerCase().contains(q) ?? false) ||
          item.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  // ── Filter Items ────────────────────────────────────────
  List<ItemModel> getFilteredItems({
    String? category,
    String? status,
    String? searchQuery,
  }) {
    List<ItemModel> result = List.from(_items);

    if (category != null && category != 'All') {
      result = result.where((i) => i.categoryId == category).toList();
    }

    if (status != null && status != 'All') {
      switch (status) {
        case 'expired':
          result = result.where((i) => i.isExpired).toList();
          break;
        case 'expiring_soon':
          result = result.where((i) => i.isExpiringSoon).toList();
          break;
        case 'low_stock':
          result = result.where((i) => i.isLowStock).toList();
          break;
        default:
          result = result.where((i) => i.status == status).toList();
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((item) =>
          item.name.toLowerCase().contains(q) ||
          (item.brand?.toLowerCase().contains(q) ?? false) ||
          item.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }

    return result;
  }

  // ── Get Item by ID ──────────────────────────────────────
  ItemModel? getItemById(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Get Recent Items ────────────────────────────────────
  List<ItemModel> getRecentItems({int limit = 10}) {
    final sorted = List<ItemModel>.from(_items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  // ── Get Items by Cabinet ───────────────────────────────
  List<ItemModel> getItemsByCabinet(String cabinetId) {
    return _items.where((item) => item.cabinetId == cabinetId).toList();
  }

  // ── Helpers ─────────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    super.dispose();
  }
}