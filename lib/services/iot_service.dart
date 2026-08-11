// lib/services/iot_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

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

  String? _connectedDeviceId;
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isDisconnecting = false;

  List<DiscoveredDevice> _discoveredDevices = [];

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

  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  // ──────────────────────────────────────────────
  // Initialize
  // ──────────────────────────────────────────────
  Future<void> initialize() async {
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request all required permissions
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ];

    final results = await permissions.request();

    // Check which permissions were granted
    for (final entry in results.entries) {
      print('📱 Permission ${entry.key}: ${entry.value}');
    }

    final allGranted = results.values.every((status) => status.isGranted);

    if (!allGranted) {
      print('⚠️ Some permissions were denied');
    } else {
      print('✅ All permissions granted');
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
  Future<bool> connectToDevice(String deviceId) async {
    print('🔗 Connecting to device: $deviceId');
    try {
      if (_isConnected || _connectionSubscription != null) {
        await disconnect();
      }
      await stopScan();
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
            _connectionStatusController.add("Connected");

            // Subscribe to BOTH door sensors
            _listenDoorSensor(CabinetDoor.upper);
            _listenDoorSensor(CabinetDoor.lower);
          }

          if (update.connectionState == DeviceConnectionState.disconnected) {
            _handleDisconnected();
          }
        },
        onError: (e) => _connectionStatusController.add("Connection error: $e"),
      );
      return true;
    } catch (e) {
      print('❌ Connection failed: $e');
      _connectionStatusController.add("Failed: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_isDisconnecting) return;
    _isDisconnecting = true;
    final deviceId = _connectedDeviceId;
    try {
      await stopScan();
      await _upperDoorSubscription?.cancel();
      await _lowerDoorSubscription?.cancel();
      await _connectionSubscription?.cancel();
      if (deviceId != null) await _ble.clearGattCache(deviceId);
    } finally {
      _upperDoorSubscription = null;
      _lowerDoorSubscription = null;
      _connectionSubscription = null;
      _connectedDeviceId = null;
      _isConnected = false;
      _upperDoorOpen = false;
      _lowerDoorOpen = false;
      _isDisconnecting = false;
      _connectionStatusController.add('Disconnected');
    }
  }

  Future<void> _handleDisconnected() async {
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
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _upperDoorSubscription?.cancel();
    _lowerDoorSubscription?.cancel();

    _doorStreamController.close();
    _connectionStatusController.close();
  }
}
