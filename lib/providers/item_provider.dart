import 'dart:async';

import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../services/firestore_service.dart';

class ItemProvider extends ChangeNotifier {
  final FirestoreService _firestoreService =
      FirestoreService();

  List<ItemModel> _items = [];

  bool _isLoading = false;

  String? _error;

  StreamSubscription? _itemsSubscription;

  // ==========================
  // Getters
  // ==========================

  List<ItemModel> get items => _items;

  bool get isLoading => _isLoading;

  String? get error => _error;

  int get totalItems => _items.length;

  List<ItemModel> get favoriteItems =>
      _items.where((item) => item.isFavorite).toList();

  List<ItemModel> get expiredItems =>
      _items.where((item) => item.expiryStatus == 'expired').toList();

  List<ItemModel> get expiringSoonItems =>
      _items
          .where(
            (item) =>
                item.expiryStatus ==
                'expiring_soon',
          )
          .toList();

  List<ItemModel> get lowStockItems =>
      _items.where((item) => item.isLowStock).toList();

  List<ItemModel> get outOfStockItems =>
      _items.where((item) => item.isOutOfStock).toList();

  // ==========================
  // Load Items
  // ==========================

  void loadItems() {
    _setLoading(true);

    _itemsSubscription?.cancel();

    _itemsSubscription =
        _firestoreService.getItems().listen(
      (items) {
        _items = items;

        _error = null;

        _setLoading(false);
      },
      onError: (error) {
        _error = error.toString();

        _setLoading(false);
      },
    );
  }

  // ==========================
  // Add Item
  // ==========================

  Future<void> addItem(
    ItemModel item,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.addItem(
        item,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  // ==========================
  // Update Item
  // ==========================

  Future<void> updateItem(
    ItemModel item,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.updateItem(
        item,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  // ==========================
  // Delete Item
  // ==========================

  Future<void> deleteItem(
    String itemId,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.deleteItem(
        itemId,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  // ==========================
  // Toggle Favorite
  // ==========================

  Future<void> toggleFavorite(
    ItemModel item,
  ) async {
    if (item.id == null) return;

    final updatedItem = item.copyWith(
      isFavorite: !item.isFavorite,
      updatedAt: DateTime.now(),
    );

    await updateItem(
      updatedItem,
    );
  }

  // ==========================
  // Search
  // ==========================

  List<ItemModel> searchItems(
    String query,
  ) {
    if (query.isEmpty) {
      return [];
    }

    final search =
        query.toLowerCase();

    return _items.where(
      (item) {
        return item.name
                .toLowerCase()
                .contains(search) ||
            item.description
                    ?.toLowerCase()
                    .contains(search) ==
                true ||
            item.tags.any(
              (tag) => tag
                  .toLowerCase()
                  .contains(search),
            );
      },
    ).toList();
  }

  // ==========================
  // Filters
  // ==========================

  List<ItemModel> getFilteredItems({
    String? category,
    String? status,
    String? searchQuery,
  }) {
    List<ItemModel> filtered =
        List.from(_items);

    if (category != null &&
        category != 'All') {
      filtered = filtered
          .where(
            (item) =>
                item.categoryId ==
                category,
          )
          .toList();
    }

    if (status != null &&
        status != 'All') {
      if (status == 'expired') {
        filtered = filtered
            .where(
              (item) =>
                  item.expiryStatus ==
                  'expired',
            )
            .toList();
      } else {
        filtered = filtered
            .where(
              (item) =>
                  item.status ==
                  status,
            )
            .toList();
      }
    }

    if (searchQuery != null &&
        searchQuery.isNotEmpty) {
      final query =
          searchQuery.toLowerCase();

      filtered = filtered.where(
        (item) {
          return item.name
                  .toLowerCase()
                  .contains(query) ||
              item.description
                      ?.toLowerCase()
                      .contains(query) ==
                  true ||
              item.tags.any(
                (tag) => tag
                    .toLowerCase()
                    .contains(query),
              );
        },
      ).toList();
    }

    return filtered;
  }

  // ==========================
  // Find Item
  // ==========================

  ItemModel? getItemById(
    String id,
  ) {
    try {
      return _items.firstWhere(
        (item) => item.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // Recent Items
  // ==========================

  List<ItemModel> getRecentItems({
    int limit = 10,
  }) {
    final sorted =
        List<ItemModel>.from(_items);

    sorted.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return sorted.take(limit).toList();
  }

  // ==========================
  // Helpers
  // ==========================

  void clearError() {
    _error = null;

    notifyListeners();
  }

  void _setLoading(
    bool value,
  ) {
    _isLoading = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();

    super.dispose();
  }
}