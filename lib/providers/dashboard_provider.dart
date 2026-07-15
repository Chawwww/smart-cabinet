// lib/providers/dashboard_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_model.dart';
import '../models/category_model.dart';
import '../models/cabinet_model.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';

class DashboardProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Statistics
  int _totalItems = 0;
  int _totalCabinets = 0;
  int _totalCategories = 0;
  int _expiredItems = 0;
  int _expiringSoon = 0;
  int _lowStockItems = 0;
  int _outOfStockItems = 0;
  int _recentActivityCount = 0;

  List<ItemModel> _recentItems = [];
  List<ItemModel> _expiringItems = [];

  bool _isLoading = false;
  String? _error;

  // ── Getters ──
  int get totalItems => _totalItems;
  int get totalCabinets => _totalCabinets;
  int get totalCategories => _totalCategories;
  int get expiredItems => _expiredItems;
  int get expiringSoon => _expiringSoon;
  int get lowStockItems => _lowStockItems;
  int get outOfStockItems => _outOfStockItems;
  int get recentActivityCount => _recentActivityCount;
  List<ItemModel> get recentItems => _recentItems;
  List<ItemModel> get expiringItems => _expiringItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Load Dashboard Data ──
  void loadDashboard({
    required ItemProvider itemProvider,
    required CategoryProvider categoryProvider,
    required CabinetProvider cabinetProvider,
  }) {
    _setLoading(true);

    try {
      final items = itemProvider.items;
      final cabinets = cabinetProvider.cabinets;
      final categories = categoryProvider.categories;

      _totalItems = items.length;
      _totalCabinets = cabinets.length;
      _totalCategories = categories.length;

      // Expiry stats
      _expiredItems = items.where((i) => i.isExpired).length;
      _expiringSoon = items.where((i) => i.isExpiringSoon && !i.isExpired).length;
      _lowStockItems = items.where((i) => i.isLowStock && !i.isOutOfStock).length;
      _outOfStockItems = items.where((i) => i.isOutOfStock).length;

      // Recent items (last 5)
      _recentItems = List.from(items)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (_recentItems.length > 5) {
        _recentItems = _recentItems.sublist(0, 5);
      }

      // Expiring items (sorted by expiry date)
      _expiringItems = items
          .where((i) => i.hasExpiry && !i.isExpired)
          .toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
      if (_expiringItems.length > 10) {
        _expiringItems = _expiringItems.sublist(0, 10);
      }

      _recentActivityCount = _recentItems.length;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  // ── Get Chart Data ──
  Map<String, int> getCategoryDistribution(List<CategoryModel> categories, List<ItemModel> items) {
    final distribution = <String, int>{};
    for (final category in categories) {
      final count = items.where((i) => i.categoryId == category.id).length;
      if (count > 0) {
        distribution[category.name] = count;
      }
    }
    return distribution;
  }

  Map<String, int> getStatusDistribution(List<ItemModel> items) {
    return {
      'Inside': items.where((i) => i.status == 'inside').length,
      'Taken': items.where((i) => i.status == 'taken').length,
      'Used': items.where((i) => i.status == 'used').length,
      'Damaged': items.where((i) => i.status == 'damaged').length,
    };
  }

  Map<String, int> getExpiryDistribution(List<ItemModel> items) {
    return {
      'Expired': items.where((i) => i.isExpired).length,
      'Expiring Soon': items.where((i) => i.isExpiringSoon && !i.isExpired).length,
      'Good': items.where((i) => i.hasExpiry && !i.isExpired && !i.isExpiringSoon).length,
      'No Expiry': items.where((i) => !i.hasExpiry).length,
    };
  }

  // ── Get Monthly Activity ──
  Map<String, int> getMonthlyActivity(List<ItemModel> items) {
    final months = <String, int>{};
    final now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      final month = now.subtract(Duration(days: 30 * i));
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      months[key] = 0;
    }

    for (final item in items) {
      final key = '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}';
      if (months.containsKey(key)) {
        months[key] = (months[key] ?? 0) + 1;
      }
    }

    return months;
  }

  // ── Clear Data ──
  void clearData() {
    _totalItems = 0;
    _totalCabinets = 0;
    _totalCategories = 0;
    _expiredItems = 0;
    _expiringSoon = 0;
    _lowStockItems = 0;
    _outOfStockItems = 0;
    _recentActivityCount = 0;
    _recentItems = [];
    _expiringItems = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
    debugPrint('🧹 DashboardProvider data cleared');
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}