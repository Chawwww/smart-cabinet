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

  static const _tempIdPrefix = 'local_';

  // ── Getters ──────────────────────────────────────────────
  List<ItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalItems => _items.length;

  String get userId => _auth.currentUser?.uid ?? '';

  List<ItemModel> get favoriteItems =>
      _items.where((i) => i.isFavorite).toList();

  List<ItemModel> get expiredItems => _items.where((i) => i.isExpired).toList();

  List<ItemModel> get expiringSoonItems =>
      _items.where((i) => i.isExpiringSoon && !i.isExpired).toList();

  List<ItemModel> get lowStockItems =>
      _items.where((i) => i.isLowStock && !i.isOutOfStock).toList();

  List<ItemModel> get outOfStockItems =>
      _items.where((i) => i.isOutOfStock).toList();

  bool _isLocalId(String? id) => id != null && id.startsWith(_tempIdPrefix);

  // ── Load Items ──────────────────────────────────────────
  void loadItems() {
    if (_itemsSubscription != null) return;
    _setLoading(true);

    _itemsSubscription = _firestoreService.getItems().listen(
      (items) {
        // Preserve any optimistic (local-only) items that Firestore
        // hasn't caught up with yet, so they don't flicker out of the
        // list while their write is still in flight.
        final localOnly = _items.where((i) => _isLocalId(i.id)).toList();
        _items = [...localOnly, ...items];
        _error = null;
        _setLoading(false);
        debugPrint(
            '📦 Items loaded: ${items.length} (+${localOnly.length} pending)');
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

  // ── Optimistic local add ────────────────────────────────
  /// Inserts [item] into the visible list immediately, before Firestore
  /// confirms the write. If it has no id yet, a temporary local id is
  /// assigned so it can be found again later (patched or removed).
  ItemModel addItemLocally(ItemModel item) {
    final localItem = item.id == null
        ? item.copyWith(
            id: '$_tempIdPrefix${DateTime.now().microsecondsSinceEpoch}')
        : item;
    _items.insert(0, localItem);
    notifyListeners();
    return localItem;
  }

  /// Removes an optimistic placeholder — e.g. because the Firestore write
  /// failed, or because it's now been superseded by the real synced item.
  void removeItemLocally(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  /// Replaces a local placeholder item (matched by [localId]) with the
  /// real item once we know its Firestore id / final data.
  void replaceLocalItem(String localId, ItemModel realItem) {
    final idx = _items.indexWhere((i) => i.id == localId);
    if (idx != -1) {
      _items[idx] = realItem;
    } else {
      _items.insert(0, realItem);
    }
    notifyListeners();
  }

  // ── Add Item ────────────────────────────────────────────
  /// Writes [item] to Firestore and returns the new document id,
  /// or null if the write failed.
  Future<String?> addItem(ItemModel item) async {
    try {
      final docId = await _firestoreService.addItem(item);
      _error = null;

      // ✅ IMPROVED: If we have a local version with same data, replace it
      final localMatches = _items.where(
        (i) =>
            _isLocalId(i.id) &&
            i.name == item.name &&
            i.createdAt == item.createdAt,
      );

      if (localMatches.isNotEmpty && localMatches.first.id != docId) {
        final localItem = localMatches.first;
        // Replace the local placeholder with the real document
        final realItem = item.copyWith(id: docId);
        _items[_items.indexOf(localItem)] = realItem;
        notifyListeners();
      }

      return docId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
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
      if (!_isLocalId(itemId)) {
        await _firestoreService.deleteItem(itemId);
      }
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
      result = result
          .where((item) =>
              item.name.toLowerCase().contains(q) ||
              (item.brand?.toLowerCase().contains(q) ?? false) ||
              item.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
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
