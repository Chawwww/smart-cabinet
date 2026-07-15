// lib/utils/network_utils.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkUtils {
  static final NetworkUtils _instance = NetworkUtils._internal();
  factory NetworkUtils() => _instance;
  NetworkUtils._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _networkStreamController = StreamController<bool>.broadcast();

  // ── Stream ──
  Stream<bool> get networkStream => _networkStreamController.stream;

  // ── Check Connection ──
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  // ── Get Connection Type ──
  Future<String> getConnectionType() async {
    try {
      final result = await _connectivity.checkConnectivity();
      switch (result) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'Mobile Data';
        case ConnectivityResult.ethernet:
          return 'Ethernet';
        case ConnectivityResult.vpn:
          return 'VPN';
        case ConnectivityResult.bluetooth:
          return 'Bluetooth';
        case ConnectivityResult.other:
          return 'Other';
        default:
          return 'None';
      }
    } catch (_) {
      return 'Unknown';
    }
  }

  // ── Listen for Changes ──
  void startListening() {
    _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
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