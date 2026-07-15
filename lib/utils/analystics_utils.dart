// lib/utils/analytics_utils.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

class AnalyticsUtils {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ── Log Screen View ──
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      if (kDebugMode) print('Analytics screen view error: $e');
    }
  }

  // ── Log Event ──
  static Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      if (kDebugMode) print('Analytics event error: $e');
    }
  }

  // ── Log Login ──
  static Future<void> logLogin({String? method}) async {
    await logEvent(
      name: 'login',
      parameters: {'method': method ?? 'email'},
    );
  }

  // ── Log Sign Up ──
  static Future<void> logSignUp({String? method}) async {
    await logEvent(
      name: 'sign_up',
      parameters: {'method': method ?? 'email'},
    );
  }

  // ── Log Logout ──
  static Future<void> logLogout() async {
    await logEvent(name: 'logout');
  }

  // ── Log Item Added ──
  static Future<void> logItemAdded({
    required String itemName,
    required String category,
    int? quantity,
  }) async {
    await logEvent(
      name: 'item_added',
      parameters: {
        'item_name': itemName,
        'category': category,
        'quantity': quantity ?? 1,
      },
    );
  }

  // ── Log Item Removed ──
  static Future<void> logItemRemoved({
    required String itemName,
    required String reason,
  }) async {
    await logEvent(
      name: 'item_removed',
      parameters: {
        'item_name': itemName,
        'reason': reason,
      },
    );
  }

  // ── Log Item Taken ──
  static Future<void> logItemTaken({
    required String itemName,
    required int quantity,
  }) async {
    await logEvent(
      name: 'item_taken',
      parameters: {
        'item_name': itemName,
        'quantity': quantity,
      },
    );
  }

  // ── Log AI Search ──
  static Future<void> logAISearch({required String query, int? resultCount}) async {
    await logEvent(
      name: 'ai_search',
      parameters: {
        'query': query,
        'result_count': resultCount ?? 0,
      },
    );
  }

  // ── Log AI AutoFill ──
  static Future<void> logAIAutoFill({
    required String source, // 'name' or 'image'
    required int fieldsFilled,
  }) async {
    await logEvent(
      name: 'ai_autofill',
      parameters: {
        'source': source,
        'fields_filled': fieldsFilled,
      },
    );
  }

  // ── Log BLE Connect ──
  static Future<void> logBLEConnect({required bool success}) async {
    await logEvent(
      name: 'ble_connect',
      parameters: {'success': success},
    );
  }

  // ── Log Door Event ──
  static Future<void> logDoorEvent({
    required String doorId,
    required String status,
  }) async {
    await logEvent(
      name: 'door_event',
      parameters: {
        'door_id': doorId,
        'status': status,
      },
    );
  }

  // ── Log Error ──
  static Future<void> logError({
    required String error,
    required String context,
    Map<String, dynamic>? additionalParams,
  }) async {
    await logEvent(
      name: 'app_error',
      parameters: {
        'error': error,
        'context': context,
        ...?additionalParams,
      },
    );
  }

  // ── Log Feature Usage ──
  static Future<void> logFeatureUsage({
    required String feature,
    Map<String, dynamic>? parameters,
  }) async {
    await logEvent(
      name: 'feature_usage',
      parameters: {
        'feature': feature,
        ...?parameters,
      },
    );
  }

  // ── Set User ID ──
  static Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      if (kDebugMode) print('Analytics set user ID error: $e');
    }
  }

  // ── Set User Property ──
  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      if (kDebugMode) print('Analytics set user property error: $e');
    }
  }

  // ── Get Analytics Observer ──
  static AnalyticsObserver getObserver() {
    return AnalyticsObserver(analytics: _analytics);
  }
}