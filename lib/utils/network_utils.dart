// lib/utils/network_utils.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkUtils {
  static final NetworkUtils _instance = NetworkUtils._internal();
  factory NetworkUtils() => _instance;
  NetworkUtils._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _networkStreamController =
      StreamController<bool>.broadcast();

  // ── Stream ──
  Stream<bool> get networkStream => _networkStreamController.stream;

  // ── Check Connection ──
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((connection) => connection != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ── Get Connection Type ──
  Future<String> getConnectionType() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.contains(ConnectivityResult.wifi)) return 'WiFi';
      if (result.contains(ConnectivityResult.mobile)) return 'Mobile Data';
      if (result.contains(ConnectivityResult.ethernet)) return 'Ethernet';
      if (result.contains(ConnectivityResult.vpn)) return 'VPN';
      if (result.contains(ConnectivityResult.bluetooth)) return 'Bluetooth';
      if (result.contains(ConnectivityResult.other)) return 'Other';
      return 'None';
    } catch (_) {
      return 'Unknown';
    }
  }

  // ── Listen for Changes ──
  void startListening() {
    _connectivity.onConnectivityChanged.listen((results) {
      final isOnline =
          results.any((result) => result != ConnectivityResult.none);
      _networkStreamController.add(isOnline);
      debugPrint('📶 Network status: ${isOnline ? 'Online' : 'Offline'}');
    });
  }

  void stopListening() {
    _networkStreamController.close();
  }

  // ── With Connectivity Check ──
  Future<T> withConnectivity<T>(
    Future<T> Function() action, {
    T Function()? fallback,
  }) async {
    if (await isConnected()) {
      try {
        return await action();
      } catch (e) {
        debugPrint('❌ Action failed: $e');
        if (fallback != null) return fallback();
        rethrow;
      }
    } else {
      debugPrint('📶 No internet connection');
      if (fallback != null) return fallback();
      throw Exception('No internet connection');
    }
  }

  // ── Dispose ──
  void dispose() {
    _networkStreamController.close();
  }
}
