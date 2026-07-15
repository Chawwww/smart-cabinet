// lib/services/sync_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _syncIntervalKey = 'sync_interval_minutes';

  Timer? _syncTimer;
  bool _isSyncing = false;
  final Connectivity _connectivity = Connectivity();

  // ── Callbacks ──
  VoidCallback? onSyncStart;
  VoidCallback? onSyncComplete;
  Function(String error)? onSyncError;

  // ── Initialize ──
  Future<void> initialize() async {
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        debugPrint('📶 Internet restored - auto syncing...');
        performSync();
      }
    });

    // Initial sync
    await performSync();

    // Start periodic sync
    startPeriodicSync();
  }

  // ── Perform Sync ──
  Future<void> performSync() async {
    if (_isSyncing) return;
    if (await _connectivity.checkConnectivity() == ConnectivityResult.none) {
      debugPrint('📶 No internet - skipping sync');
      return;
    }

    _isSyncing = true;
    onSyncStart?.call();
    debugPrint('🔄 Starting sync...');

    try {
      // This would typically call a cloud function or API
      // For now, just reload data from Firestore
      // (Providers are already listening to Firestore streams)

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);

      onSyncComplete?.call();
      debugPrint('✅ Sync completed');
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      onSyncError?.call(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  // ── Periodic Sync ──
  void startPeriodicSync({int intervalMinutes = 30}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => performSync(),
    );
    debugPrint('⏰ Periodic sync started (every $intervalMinutes min)');
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏰ Periodic sync stopped');
  }

  // ── Get Last Sync Time ──
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // ── Force Sync ──
  Future<void> forceSync({
    required ItemProvider itemProvider,
    required CategoryProvider categoryProvider,
    required CabinetProvider cabinetProvider,
  }) async {
    debugPrint('🔄 Force syncing all providers...');

    itemProvider.reloadItems();
    categoryProvider.loadCategories();
    cabinetProvider.reloadCabinets();
    cabinetProvider.reloadBoxes();

    await performSync();
  }

  String getLastSyncText() {
    final time = getLastSyncTime();
    if (time == null) return 'Never synced';
    final diff = DateTime.now().difference(time as DateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}