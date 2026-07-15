// lib/utils/permission_utils.dart
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  // ── Check Permission Status ──
  static Future<bool> checkPermission(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  // ── Request Permission ──
  static Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  // ── Request Multiple Permissions ──
  static Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }

  // ── Check and Request ──
  static Future<bool> checkAndRequest(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await permission.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied) {
      // Open app settings
      await openAppSettings();
      return false;
    }
    return false;
  }

  // ── Camera ──
  static Future<bool> requestCamera() async {
    return await checkAndRequest(Permission.camera);
  }

  // ── Gallery / Storage ──
  static Future<bool> requestGallery() async {
    if (kIsWeb) return true;
    if (Platform.isIOS) {
      return await checkAndRequest(Permission.photos);
    } else if (Platform.isAndroid) {
      if (await checkAndRequest(Permission.storage)) return true;
      return await checkAndRequest(Permission.manageExternalStorage);
    }
    return false;
  }

  // ── Microphone ──
  static Future<bool> requestMicrophone() async {
    return await checkAndRequest(Permission.microphone);
  }

  // ── Bluetooth ──
  static Future<bool> requestBluetooth() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
      final results = await requestPermissions(permissions);
      return results.values.every((status) => status.isGranted);
    } else if (Platform.isIOS) {
      return await checkAndRequest(Permission.bluetooth);
    }
    return false;
  }

  // ── Location ──
  static Future<bool> requestLocation() async {
    return await checkAndRequest(Permission.locationWhenInUse);
  }

  // ── Notifications ──
  static Future<bool> requestNotifications() async {
    return await checkAndRequest(Permission.notification);
  }

  // ── Show Permission Dialog ──
  static Future<bool> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required Permission permission,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (result == true) {
      return await checkAndRequest(permission);
    }
    return false;
  }

  // ── Is Permission Permanently Denied ──
  static Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }
}