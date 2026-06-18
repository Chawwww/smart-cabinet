import 'dart:async';
import 'dart:convert';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_constants.dart';

class IoTService {
  static final IoTService _instance = IoTService._internal();

  factory IoTService() => _instance;

  IoTService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  String? _connectedDeviceId;

  bool _isConnected = false;
  bool _isScanning = false;

  List<DiscoveredDevice> _discoveredDevices = [];

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _doorSubscription;

  final StreamController<Map<String, dynamic>> _doorStreamController =
      StreamController.broadcast();

  final StreamController<String> _connectionStatusController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get doorEvents =>
      _doorStreamController.stream;

  Stream<String> get connectionStatus =>
      _connectionStatusController.stream;

  bool get isConnected => _isConnected;

  bool get isScanning => _isScanning;

  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  //----------------------------------------------------------
  // Initialize
  //----------------------------------------------------------

  Future<void> initialize() async {
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  //----------------------------------------------------------
  // Scan
  //----------------------------------------------------------

  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _discoveredDevices.clear();

    _scanSubscription = _ble.scanForDevices(
      withServices: [],
    ).listen(
      (device) {
        if (!_discoveredDevices.any((e) => e.id == device.id)) {
          _discoveredDevices.add(device);
        }
      },
      onError: (e) {
        _connectionStatusController.add("Scan error: $e");
      },
    );
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _isScanning = false;
  }

  //----------------------------------------------------------
  // Connect
  //----------------------------------------------------------

  Future<bool> connectToDevice(String deviceId) async {
    try {
      _connectionSubscription = _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 20),
      ).listen(
        (update) {
          if (update.connectionState ==
              DeviceConnectionState.connected) {
            _connectedDeviceId = deviceId;
            _isConnected = true;

            _connectionStatusController.add("Connected");

            _listenDoorSensor();
          }

          if (update.connectionState ==
              DeviceConnectionState.disconnected) {
            _connectedDeviceId = null;
            _isConnected = false;

            _connectionStatusController.add("Disconnected");
          }
        },
        onError: (e) {
          _connectionStatusController.add("Connection error: $e");
        },
      );

      return true;
    } catch (e) {
      _connectionStatusController.add("Failed: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    await _doorSubscription?.cancel();

    if (_connectedDeviceId != null) {
      await _ble.clearGattCache(_connectedDeviceId!);
    }

    _connectedDeviceId = null;
    _isConnected = false;

    _connectionStatusController.add("Disconnected");
  }

  //----------------------------------------------------------
  // Door Sensor
  //----------------------------------------------------------

  void _listenDoorSensor() {
    if (_connectedDeviceId == null) return;

    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.bleServiceUUID),
      characteristicId:
          Uuid.parse(AppConstants.doorSensorCharacteristic),
      deviceId: _connectedDeviceId!,
    );

    _doorSubscription =
        _ble.subscribeToCharacteristic(characteristic).listen(
      (data) {
        final value = utf8.decode(data);

        _doorStreamController.add({
          "status": value,
          "time": DateTime.now(),
        });
      },
    );
  }

  //----------------------------------------------------------
  // Servo
  //----------------------------------------------------------

  Future<void> sendServoCommand(int angle) async {
    if (_connectedDeviceId == null) {
      throw Exception("No device connected");
    }

    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.bleServiceUUID),
      characteristicId:
          Uuid.parse(AppConstants.servoCharacteristic),
      deviceId: _connectedDeviceId!,
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: utf8.encode(angle.toString()),
    );
  }

  //----------------------------------------------------------
  // LED
  //----------------------------------------------------------

  Future<void> sendLEDCommand(bool on) async {
    if (_connectedDeviceId == null) {
      throw Exception("No device connected");
    }

    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.bleServiceUUID),
      characteristicId:
          Uuid.parse(AppConstants.ledCharacteristic),
      deviceId: _connectedDeviceId!,
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: utf8.encode(on ? "1" : "0"),
    );
  }

  //----------------------------------------------------------
  // Open Door
  //----------------------------------------------------------

  Future<void> openDoor() async {
    await sendServoCommand(90);
  }

  Future<void> closeDoor() async {
    await sendServoCommand(0);
  }

  //----------------------------------------------------------
  // Dispose
  //----------------------------------------------------------

  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _doorSubscription?.cancel();

    _doorStreamController.close();
    _connectionStatusController.close();
  }
}