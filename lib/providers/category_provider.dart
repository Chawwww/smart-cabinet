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

  // ── Getters ──────────────────────────────────────────────
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCategories => _categories.length;

  // ── Load Categories ─────────────────────────────────────
  void loadCategories() {
    if (_subscription != null) return;
    _setLoading(true);

    _subscription = _firestoreService.getCategories().listen(
      (categories) {
        _categories = categories;
        _error = null;
        _setLoading(false);
        debugPrint('📂 Categories loaded: ${categories.length}');
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

  // ── Add Category ────────────────────────────────────────
  Future<void> addCategory(CategoryModel category) async {
    try {
      _setLoading(true);
      await _firestoreService.addCategory(category);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  // ── Update Category ─────────────────────────────────────
  Future<void> updateCategory(CategoryModel category) async {
    try {
      _setLoading(true);
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
      await _firestoreService.deleteCategory(categoryId);
      _error = null;
    } catch (e) {
      _error = e.toString();
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