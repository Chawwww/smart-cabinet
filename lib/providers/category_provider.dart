// lib/providers/category_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/firestore_service.dart';

class CategoryProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _subscription;

  static const _tempIdPrefix = 'local_';

  // ── Getters ──────────────────────────────────────────────
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCategories => _categories.length;

  bool _isLocalId(String? id) => id != null && id.startsWith(_tempIdPrefix);

  // ── Load Categories ─────────────────────────────────────
  void loadCategories() {
    if (_subscription != null) return;
    _setLoading(true);

    _subscription = _firestoreService.getCategories().listen(
      (categories) {
        // Preserve any optimistic (local-only) categories
        final localOnly = _categories.where((i) => _isLocalId(i.id)).toList();
        _categories = [...localOnly, ...categories];
        _error = null;
        _setLoading(false);
        debugPrint('📂 Categories loaded: ${categories.length} (+${localOnly.length} pending)');
      },
      onError: (error) {
        _error = error.toString();
        _setLoading(false);
      },
    );
  }

  void reloadCategories() {
    _subscription?.cancel();
    _subscription = null;
    _categories = [];
    loadCategories();
  }

  // ✅ Clear Data on Logout
  void clearData() {
    _subscription?.cancel();
    _subscription = null;
    _categories = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
    debugPrint('🧹 CategoryProvider data cleared');
  }

  // ── Optimistic local add ────────────────────────────────
  /// Inserts [category] into the visible list immediately, before Firestore
  /// confirms the write. If it has no id yet, a temporary local id is
  /// assigned so it can be found again later.
  CategoryModel _addCategoryLocally(CategoryModel category) {
    final localCategory = category.id == null
        ? category.copyWith(
            id: '$_tempIdPrefix${DateTime.now().microsecondsSinceEpoch}')
        : category;
    _categories.insert(0, localCategory);
    notifyListeners();
    return localCategory;
  }

  /// Removes an optimistic placeholder
  void _removeCategoryLocally(String id) {
    _categories.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  // ── Add Category (with optimistic update) ──────────────
  Future<void> addCategory(CategoryModel category) async {
    try {
      _setLoading(true);
      
      // ✅ ADD OPTIMISTIC CATEGORY FIRST (immediate UI feedback)
      final tempCategory = _addCategoryLocally(category);
      debugPrint('📂 Added optimistic category: ${tempCategory.id}');
      
      // Save to Firestore
      await _firestoreService.addCategory(category);
      
      // ✅ Remove local placeholder and reload
      _removeCategoryLocally(tempCategory.id!);
      _error = null;
      
      // ✅ Reload to get the real data
      reloadCategories();
      
    } catch (e) {
      _error = e.toString();
      // Remove optimistic category on error
      if (category.id != null && _isLocalId(category.id)) {
        _removeCategoryLocally(category.id!);
      }
    }
    _setLoading(false);
  }

  // ── Update Category ─────────────────────────────────────
  Future<void> updateCategory(CategoryModel category) async {
    try {
      _setLoading(true);
      
      // Update locally first
      final idx = _categories.indexWhere((i) => i.id == category.id);
      if (idx != -1) {
        _categories[idx] = category;
        notifyListeners();
      }
      
      await _firestoreService.updateCategory(category);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  // ── Delete Category ─────────────────────────────────────
  Future<void> deleteCategory(String categoryId) async {
    try {
      _setLoading(true);
      
      // Remove locally first
      _categories.removeWhere((i) => i.id == categoryId);
      notifyListeners();
      
      await _firestoreService.deleteCategory(categoryId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      reloadCategories();
    }
    _setLoading(false);
  }

  // ── Find Category by ID ─────────────────────────────────
  CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Find Category by Name ──────────────────────────────
  CategoryModel? getCategoryByName(String name) {
    try {
      return _categories.firstWhere(
        (category) => category.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Search Categories ──────────────────────────────────
  List<CategoryModel> searchCategories(String keyword) {
    if (keyword.isEmpty) return _categories;
    final query = keyword.toLowerCase();
    return _categories.where(
      (category) => category.name.toLowerCase().contains(query),
    ).toList();
  }

  // ── Get Sorted Categories ──────────────────────────────
  List<CategoryModel> getSortedCategories() {
    final sorted = List<CategoryModel>.from(_categories);
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  // ── Helpers ─────────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}