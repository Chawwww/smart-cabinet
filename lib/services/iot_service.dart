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

class IoTService {
  static final IoTService _instance = IoTService._internal();
  factory IoTService() => _instance;
  IoTService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  String? _connectedDeviceId;
  bool _isConnected = false;
  bool _isScanning  = false;

  List<DiscoveredDevice> _discoveredDevices = [];

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  // CHANGED: separate door subscriptions for upper and lower
  StreamSubscription<List<int>>? _upperDoorSubscription;
  StreamSubscription<List<int>>? _lowerDoorSubscription;

  // CHANGED: door events now carry which door (upper/lower) triggered
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
  bool get isScanning  => _isScanning;
  bool get isUpperDoorOpen => _upperDoorOpen;
  bool get isLowerDoorOpen => _lowerDoorOpen;

  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  // ──────────────────────────────────────────────
  // Initialize
  // ──────────────────────────────────────────────
  Future<void> initialize() async {
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  // ──────────────────────────────────────────────
  // Scan
  // ──────────────────────────────────────────────
  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;
    _discoveredDevices.clear();

    _scanSubscription = _ble.scanForDevices(withServices: []).listen(
      (device) {
        if (!_discoveredDevices.any((e) => e.id == device.id)) {
          _discoveredDevices.add(device);
        }
      },
      onError: (e) => _connectionStatusController.add("Scan error: $e"),
    );
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _isScanning = false;
  }

  // ──────────────────────────────────────────────
  // Connect
  // ──────────────────────────────────────────────
  Future<bool> connectToDevice(String deviceId) async {
    try {
      _connectionSubscription = _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 20),
      ).listen(
        (update) {
          if (update.connectionState == DeviceConnectionState.connected) {
            _connectedDeviceId = deviceId;
            _isConnected = true;
            _connectionStatusController.add("Connected");

            // CHANGED: subscribe to BOTH door sensors
            _listenDoorSensor(CabinetDoor.upper);
            _listenDoorSensor(CabinetDoor.lower);
          }

          if (update.connectionState == DeviceConnectionState.disconnected) {
            _connectedDeviceId = null;
            _isConnected = false;
            _connectionStatusController.add("Disconnected");
          }
        },
        onError: (e) => _connectionStatusController.add("Connection error: $e"),
      );
      return true;
    } catch (e) {
      _connectionStatusController.add("Failed: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    await _upperDoorSubscription?.cancel();
    await _lowerDoorSubscription?.cancel();

    if (_connectedDeviceId != null) {
      await _ble.clearGattCache(_connectedDeviceId!);
    }

    _connectedDeviceId = null;
    _isConnected = false;
    _connectionStatusController.add("Disconnected");
  }

  // ──────────────────────────────────────────────
  // Door Sensor — now per-door
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

        if (door == CabinetDoor.upper) {
          _upperDoorOpen = isOpen;
        } else {
          _lowerDoorOpen = isOpen;
        }

        _doorStreamController.add({
          "door":   door.id,      // "upper" or "lower"
          "status": value,
          "isOpen": isOpen,
          "time":   DateTime.now(),
        });
      },
      onError: (e) => _connectionStatusController.add(
          "${door.label} sensor error: $e"),
    );

    if (door == CabinetDoor.upper) {
      _upperDoorSubscription = sub;
    } else {
      _lowerDoorSubscription = sub;
    }
  }

  // ──────────────────────────────────────────────
  // Servo — now requires specifying which door
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
  // LED — now requires specifying which door
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
    await sendServoCommand(door, 90);
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