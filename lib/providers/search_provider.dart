// lib/providers/search_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_model.dart';
import '../models/category_model.dart';
import '../services/ai_service.dart';
import '../providers/item_provider.dart';

class SearchProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';
  List<ItemModel> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _isAiSearching = false;
  String? _error;
  SmartSearchResult? _aiResult;

  // ── Getters ──
  String get searchQuery => _searchQuery;
  List<ItemModel> get searchResults => _searchResults;
  List<String> get searchHistory => _searchHistory;
  bool get isSearching => _isSearching;
  bool get isAiSearching => _isAiSearching;
  String? get error => _error;
  SmartSearchResult? get aiResult => _aiResult;
  int get resultCount => _searchResults.length;

  // ── Search Items ──
  void searchItems(String query, List<ItemModel> allItems) {
    _searchQuery = query.trim();
    _isSearching = true;
    _error = null;

    if (_searchQuery.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    final q = _searchQuery.toLowerCase();
    _searchResults = allItems.where((item) {
      return item.name.toLowerCase().contains(q) ||
          (item.description?.toLowerCase().contains(q) ?? false) ||
          (item.brand?.toLowerCase().contains(q) ?? false) ||
          (item.note?.toLowerCase().contains(q) ?? false) ||
          item.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    // Add to history
    if (_searchResults.isNotEmpty && !_searchHistory.contains(_searchQuery)) {
      _searchHistory.insert(0, _searchQuery);
      if (_searchHistory.length > 20) _searchHistory.removeLast();
    }

    _isSearching = false;
    notifyListeners();
  }

  // ── AI Smart Search ──
  Future<void> aiSmartSearch(String query, List<String> cabinetItemNames) async {
    if (query.trim().isEmpty) return;

    _searchQuery = query.trim();
    _isAiSearching = true;
    _aiResult = null;
    _error = null;
    notifyListeners();

    try {
      _aiResult = await AIService().smartSearch(query, cabinetItemNames);
      
      // Add to history
      if (!_searchHistory.contains(_searchQuery)) {
        _searchHistory.insert(0, _searchQuery);
        if (_searchHistory.length > 20) _searchHistory.removeLast();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isAiSearching = false;
      notifyListeners();
    }
  }

  // ── Filter by Category ──
  List<ItemModel> filterByCategory(String categoryId, List<ItemModel> items) {
    if (categoryId.isEmpty || categoryId == 'All') return items;
    return items.where((i) => i.categoryId == categoryId).toList();
  }

  // ── Filter by Status ──
  List<ItemModel> filterByStatus(String status, List<ItemModel> items) {
    if (status.isEmpty || status == 'All') return items;
    switch (status) {
      case 'expired':
        return items.where((i) => i.isExpired).toList();
      case 'expiring_soon':
        return items.where((i) => i.isExpiringSoon && !i.isExpired).toList();
      case 'low_stock':
        return items.where((i) => i.isLowStock && !i.isOutOfStock).toList();
      case 'out_of_stock':
        return items.where((i) => i.isOutOfStock).toList();
      default:
        return items.where((i) => i.status == status).toList();
    }
  }

  // ── Clear ──
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _aiResult = null;
    _error = null;
    _isSearching = false;
    _isAiSearching = false;
    notifyListeners();
  }

  void clearHistory() {
    _searchHistory = [];
    notifyListeners();
  }

  void removeFromHistory(String query) {
    _searchHistory.remove(query);
    notifyListeners();
  }

  // ── Load History ──
  void loadHistory(List<String> history) {
    _searchHistory = history;
    notifyListeners();
  }

  // ── Clear Data ──
  void clearData() {
    _searchQuery = '';
    _searchResults = [];
    _searchHistory = [];
    _aiResult = null;
    _error = null;
    _isSearching = false;
    _isAiSearching = false;
    notifyListeners();
    debugPrint('🧹 SearchProvider data cleared');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}