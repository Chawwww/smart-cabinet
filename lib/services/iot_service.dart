// lib/services/iot_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';

// Which door — used everywhere a door needs to be identified
enum CabinetDoor { upper, lower }

extension CabinetDoorX on CabinetDoor {
  String get id => this == CabinetDoor.upper
      ? AppConstants.doorUpper
      : AppConstants.doorLower;

  String get label => this == CabinetDoor.upper ? 'Upper Door' : 'Lower Door';
}

// String -> CabinetDoor helper
CabinetDoor? cabinetDoorFromId(String? id) {
  switch (id) {
    case AppConstants.doorUpper:
      return CabinetDoor.upper;
    case AppConstants.doorLower:
      return CabinetDoor.lower;
    default:
      return null;
  }
}

class IoTService {
  static final IoTService _instance = IoTService._internal();
  factory IoTService() => _instance;
  IoTService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  static const MethodChannel _backgroundChannel =
      MethodChannel('smart_cabinet/ble_background');
  static const String _lastDeviceKey = 'ble_last_device_id';

  String? _connectedDeviceId;
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isDisconnecting = false;
  bool _manualDisconnect = false;
  bool _initialized = false;
  String? _preferredDeviceId;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  final List<DiscoveredDevice> _discoveredDevices = [];

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  StreamSubscription<List<int>>? _upperDoorSubscription;
  StreamSubscription<List<int>>? _lowerDoorSubscription;

  final StreamController<Map<String, dynamic>> _doorStreamController =
      StreamController.broadcast();

  final StreamController<String> _connectionStatusController =
      StreamController.broadcast();

  // Track latest known state of each door
  bool _upperDoorOpen = false;
  bool _lowerDoorOpen = false;

  Stream<Map<String, dynamic>> get doorEvents => _doorStreamController.stream;
  Stream<String> get connectionStatus => _connectionStatusController.stream;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  bool get isUpperDoorOpen => _upperDoorOpen;
  bool get isLowerDoorOpen => _lowerDoorOpen;

  String? get connectedDeviceId => _connectedDeviceId;
  String? get preferredDeviceId => _preferredDeviceId;
  bool get isReconnecting => _reconnectTimer?.isActive ?? false;

  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  // ──────────────────────────────────────────────
  // Initialize
  // ──────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _preferredDeviceId = prefs.getString(_lastDeviceKey);

    // Do not interrupt startup with a permission dialog. Once the user has
    // connected at least once, reconnect silently on subsequent app starts.
    final canReconnect = await Permission.bluetoothConnect.isGranted;
    if (canReconnect && _preferredDeviceId != null) {
      unawaited(connectToDevice(_preferredDeviceId!, remember: false));
    }
  }

  // ──────────────────────────────────────────────
  // Scan
  // ──────────────────────────────────────────────
  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;
    _discoveredDevices.clear();

    print('🔍 Starting BLE scan...');

    _scanSubscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        print('🔍 Found device: ${device.name} (${device.id})');
        if (!_discoveredDevices.any((e) => e.id == device.id)) {
          _discoveredDevices.add(device);
          _connectionStatusController.add("Found: ${device.name}");
        }
      },
      onError: (e) {
        print('❌ Scan error: $e');
        _connectionStatusController.add("Scan error: $e");
        _isScanning = false;
      },
    );

    // Auto-stop after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_isScanning) {
        stopScan();
        _connectionStatusController
            .add("Scan complete. Found ${_discoveredDevices.length} devices.");
        print('✅ Scan complete. Found ${_discoveredDevices.length} devices.');
      }
    });
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _isScanning = false;
  }

  // ──────────────────────────────────────────────
  // Connect
  // ──────────────────────────────────────────────
  Future<bool> connectToDevice(String deviceId, {bool remember = true}) async {
    print('🔗 Connecting to device: $deviceId');
    try {
      // Android 13+ needs this before it can visibly run the BLE foreground
      // service. A denial does not block a normal foreground connection.
      if (Platform.isAndroid && await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      _manualDisconnect = false;
      _reconnectTimer?.cancel();
      _preferredDeviceId = deviceId;
      if (remember) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastDeviceKey, deviceId);
      }

      await _cancelActiveConnection();
      await stopScan();
      _connectionStatusController.add('Connecting');
      _connectionSubscription = _ble
          .connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 20),
      )
          .listen(
        (update) {
          print('📡 Connection state: ${update.connectionState}');
          if (update.connectionState == DeviceConnectionState.connected) {
            _connectedDeviceId = deviceId;
            _isConnected = true;
            _reconnectAttempt = 0;
            _reconnectTimer?.cancel();
            _connectionStatusController.add("Connected");
            unawaited(_startBackgroundConnection(deviceId));

            // Subscribe to BOTH door sensors
            _listenDoorSensor(CabinetDoor.upper);
            _listenDoorSensor(CabinetDoor.lower);
          }

          if (update.connectionState == DeviceConnectionState.disconnected) {
            _handleDisconnected(deviceId);
          }
        },
        onError: (e) {
          _connectionStatusController.add("Connection error: $e");
          _handleDisconnected(deviceId);
        },
      );
      return true;
    } catch (e) {
      print('❌ Connection failed: $e');
      _connectionStatusController.add("Failed: $e");
      _scheduleReconnect(deviceId);
      return false;
    }
  }

  /// Disconnect at the user's request and forget the automatic reconnect
  /// target. Switching cabinets uses [_cancelActiveConnection] instead.
  Future<void> disconnect() async {
    if (_isDisconnecting) return;
    _isDisconnecting = true;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    try {
      await _cancelActiveConnection();
      _preferredDeviceId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastDeviceKey);
      await _stopBackgroundConnection();
    } finally {
      _isDisconnecting = false;
      _connectionStatusController.add('Disconnected');
    }
  }

  Future<void> _cancelActiveConnection() async {
    await stopScan();
    await _upperDoorSubscription?.cancel();
    await _lowerDoorSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _upperDoorSubscription = null;
    _lowerDoorSubscription = null;
    _connectionSubscription = null;
    _connectedDeviceId = null;
    _isConnected = false;
    _upperDoorOpen = false;
    _lowerDoorOpen = false;
  }

  Future<void> _handleDisconnected(String deviceId) async {
    if (_isDisconnecting) return;
    await _upperDoorSubscription?.cancel();
    await _lowerDoorSubscription?.cancel();
    _upperDoorSubscription = null;
    _lowerDoorSubscription = null;
    _connectionSubscription = null;
    _connectedDeviceId = null;
    _isConnected = false;
    _upperDoorOpen = false;
    _lowerDoorOpen = false;
    _connectionStatusController.add('Disconnected');
    _scheduleReconnect(deviceId);
  }

  void _scheduleReconnect(String deviceId) {
    if (_manualDisconnect || _preferredDeviceId != deviceId) return;
    if (_reconnectTimer?.isActive ?? false) return;

    final delaySeconds = _reconnectAttempt == 0
        ? 2
        : (_reconnectAttempt < 5 ? 1 << _reconnectAttempt : 30);
    _reconnectAttempt++;
    _connectionStatusController.add('Reconnecting');
    unawaited(_updateBackgroundConnection('Reconnecting to cabinet…'));
    _reconnectTimer =
        Timer(Duration(seconds: delaySeconds.clamp(2, 30).toInt()), () {
      if (!_manualDisconnect &&
          !_isConnected &&
          _preferredDeviceId == deviceId) {
        unawaited(connectToDevice(deviceId, remember: false));
      }
    });
  }

  Future<void> _startBackgroundConnection(String deviceId) async {
    if (!Platform.isAndroid) return;
    try {
      await _backgroundChannel.invokeMethod('start', {
        'message': 'Connected to smart cabinet',
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      print('⚠️ Could not start BLE foreground service: $e');
    }
  }

  Future<void> _updateBackgroundConnection(String message) async {
    if (!Platform.isAndroid) return;
    try {
      await _backgroundChannel.invokeMethod('update', {'message': message});
    } on PlatformException catch (_) {}
  }

  Future<void> _stopBackgroundConnection() async {
    if (!Platform.isAndroid) return;
    try {
      await _backgroundChannel.invokeMethod('stop');
    } on PlatformException catch (_) {}
  }

  // ──────────────────────────────────────────────
  // Door Sensor — per-door, with change detection
  // ──────────────────────────────────────────────
  void _listenDoorSensor(CabinetDoor door) {
    if (_connectedDeviceId == null) return;

    final charUuid = door == CabinetDoor.upper
        ? AppConstants.upperDoorSensorCharacteristic
        : AppConstants.lowerDoorSensorCharacteristic;

    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.bleServiceUUID),
      characteristicId: Uuid.parse(charUuid),
      deviceId: _connectedDeviceId!,
    );

    final sub = _ble.subscribeToCharacteristic(characteristic).listen(
      (data) {
        final value = utf8.decode(data); // "OPEN" or "CLOSED"
        final isOpen = value.trim().toUpperCase() == "OPEN";

        // Remember what this door's state was BEFORE this update.
        final previousState =
            door == CabinetDoor.upper ? _upperDoorOpen : _lowerDoorOpen;

        if (door == CabinetDoor.upper) {
          _upperDoorOpen = isOpen;
        } else {
          _lowerDoorOpen = isOpen;
        }

        // Only emit when this specific door's state actually flipped.
        if (isOpen == previousState) return;

        _doorStreamController.add({
          "door": door.id, // "upper" or "lower"
          "status": value,
          "isOpen": isOpen,
          "time": DateTime.now(),
        });
      },
      onError: (e) =>
          _connectionStatusController.add("${door.label} sensor error: $e"),
    );

    if (door == CabinetDoor.upper) {
      _upperDoorSubscription = sub;
    } else {
      _lowerDoorSubscription = sub;
    }
  }

  // ──────────────────────────────────────────────
  // Servo — requires specifying which door
  // ──────────────────────────────────────────────
  Future<void> sendServoCommand(CabinetDoor door, int angle) async {
    if (_connectedDeviceId == null) {
      throw Exception("No device connected");
    }

    final charUuid = door == CabinetDoor.upper
        ? AppConstants.upperServoCharacteristic
        : AppConstants.lowerServoCharacteristic;

    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.bleServiceUUID),
      characteristicId: Uuid.parse(charUuid),
      deviceId: _connectedDeviceId!,
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: utf8.encode(angle.toString()),
    );
  }

  // ──────────────────────────────────────────────
  // LED — requires specifying which door
  // ──────────────────────────────────────────────
  Future<void> sendLEDCommand(CabinetDoor door, bool on) async {
    if (_connectedDeviceId == null) {
      throw Exception("No device connected");
    }

    final charUuid = door == CabinetDoor.upper
        ? AppConstants.upperLedCharacteristic
        : AppConstants.lowerLedCharacteristic;

    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.bleServiceUUID),
      characteristicId: Uuid.parse(charUuid),
      deviceId: _connectedDeviceId!,
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: utf8.encode(on ? "1" : "0"),
    );
  }

  // ──────────────────────────────────────────────
  // Open / Close — per door
  // ──────────────────────────────────────────────
  Future<void> openDoor(CabinetDoor door) async {
    // Must be > 90 to match the firmware's "angle > 90 => unlock" check.
    await sendServoCommand(door, 180);
  }

  Future<void> closeDoor(CabinetDoor door) async {
    await sendServoCommand(door, 0);
  }

  // Convenience: open/close both doors together
  Future<void> openBothDoors() async {
    await openDoor(CabinetDoor.upper);
    await openDoor(CabinetDoor.lower);
  }

  Future<void> closeBothDoors() async {
    await closeDoor(CabinetDoor.upper);
    await closeDoor(CabinetDoor.lower);
  }

  // ──────────────────────────────────────────────
  // Dispose
  // ──────────────────────────────────────────────
  void dispose() {
    _reconnectTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _upperDoorSubscription?.cancel();
    _lowerDoorSubscription?.cancel();

    _doorStreamController.close();
    _connectionStatusController.close();
  }
}
