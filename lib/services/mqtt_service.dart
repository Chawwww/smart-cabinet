// lib/services/mqtt_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/app_constants.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;

  // Door state callbacks
  Function(bool isOpen)? onUpperDoorChanged;
  Function(bool isOpen)? onLowerDoorChanged;
  Function(String door, bool isOpen)? onAnyDoorChanged;

  // LED state callbacks
  Function(bool isOn)? onUpperLedChanged;
  Function(bool isOn)? onLowerLedChanged;

  final StreamController<Map<String, dynamic>> _doorStreamController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get doorEvents => _doorStreamController.stream;

  bool get isConnected => _isConnected;

  // ── Initialize ──
  Future<bool> initialize() async {
    try {
      _client = MqttServerClient(
        AppConstants.mqttServer,
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
      );

      _client!.port = AppConstants.mqttPort;
      _client!.keepAlivePeriod = const Duration(seconds: 20);
      _client!.autoReconnect = true;
      _client!.logging(on: false);

      _client!.onDisconnected = () {
        _isConnected = false;
        debugPrint('🔴 MQTT disconnected');
      };

      _client!.onSubscribed = (topic) {
        debugPrint('📡 Subscribed to: $topic');
      };

      _client!.onUnsubscribed = (topic) {
        debugPrint('📡 Unsubscribed from: $topic');
      };

      final connMessage = MqttConnectMessage()
          .withClientIdentifier('flutter_client_${DateTime.now().millisecondsSinceEpoch}')
          .withWillTopic('willtopic')
          .withWillMessage('Client disconnected')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        debugPrint('✅ MQTT connected to ${AppConstants.mqttServer}');
        _subscribeToTopics();
        return true;
      } else {
        debugPrint('❌ MQTT connection failed: ${_client!.connectionStatus}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ MQTT initialization error: $e');
      return false;
    }
  }

  void _subscribeToTopics() {
    final topics = [
      AppConstants.mqttDoorTopicUpper,
      AppConstants.mqttDoorTopicLower,
      AppConstants.mqttLedTopicUpper,
      AppConstants.mqttLedTopicLower,
    ];

    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (final event in events) {
        _handleMessage(event.topic, event.payload as MqttPublishMessage);
      }
    });
  }

  void _handleMessage(String topic, MqttPublishMessage message) {
    final payload = MqttPublishPayload.bytesToStringAsString(
      message.payload.message,
    );

    debugPrint('📨 MQTT message: $topic -> $payload');

    final lowerPayload = payload.trim().toLowerCase();

    switch (topic) {
      case 'smart_cabinet/door/upper':
        final isOpen = lowerPayload == 'open';
        onUpperDoorChanged?.call(isOpen);
        onAnyDoorChanged?.call('upper', isOpen);
        _doorStreamController.add({
          'door': 'upper',
          'status': lowerPayload,
          'isOpen': isOpen,
          'time': DateTime.now(),
        });
        break;

      case 'smart_cabinet/door/lower':
        final isOpen = lowerPayload == 'open';
        onLowerDoorChanged?.call(isOpen);
        onAnyDoorChanged?.call('lower', isOpen);
        _doorStreamController.add({
          'door': 'lower',
          'status': lowerPayload,
          'isOpen': isOpen,
          'time': DateTime.now(),
        });
        break;

      case 'smart_cabinet/led/upper':
        final isOn = lowerPayload == '1' || lowerPayload == 'true' || lowerPayload == 'on';
        onUpperLedChanged?.call(isOn);
        break;

      case 'smart_cabinet/led/lower':
        final isOn = lowerPayload == '1' || lowerPayload == 'true' || lowerPayload == 'on';
        onLowerLedChanged?.call(isOn);
        break;
    }
  }

  // ── Publish Commands ──
  Future<void> publishDoorCommand(String door, bool open) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT not connected');
    }

    final topic = door == 'upper'
        ? AppConstants.mqttServoTopicUpper
        : AppConstants.mqttServoTopicLower;

    final message = MqttClientPayloadBuilder()
      ..addString(open ? '90' : '0');

    await _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      message.payload!,
    );
  }

  Future<void> publishLedCommand(String door, bool on) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT not connected');
    }

    final topic = door == 'upper'
        ? AppConstants.mqttLedTopicUpper
        : AppConstants.mqttLedTopicLower;

    final message = MqttClientPayloadBuilder()
      ..addString(on ? '1' : '0');

    await _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      message.payload!,
    );
  }

  Future<void> openDoor(String door) async {
    await publishDoorCommand(door, true);
  }

  Future<void> closeDoor(String door) async {
    await publishDoorCommand(door, false);
  }

  Future<void> setLed(String door, bool on) async {
    await publishLedCommand(door, on);
  }

  // ── Disconnect ──
  Future<void> disconnect() async {
    try {
      await _client?.disconnect();
      _isConnected = false;
      debugPrint('🔴 MQTT disconnected');
    } catch (e) {
      debugPrint('⚠️ MQTT disconnect error: $e');
    }
  }

  void dispose() {
    _doorStreamController.close();
    disconnect();
  }
}