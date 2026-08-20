// lib/screens/smart_cabinet_control_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/iot_service.dart';
import '../providers/item_provider.dart';
import '../providers/cabinet_provider.dart';
import 'add_edit_item_screen.dart';

class SmartCabinetControlScreen extends StatefulWidget {
  const SmartCabinetControlScreen({super.key});

  @override
  State<SmartCabinetControlScreen> createState() =>
      _SmartCabinetControlScreenState();
}

class _SmartCabinetControlScreenState extends State<SmartCabinetControlScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _selectedDeviceId;
  List<DiscoveredDevice> _devices = [];

  // Door states
  bool _upperDoorOpen = false;
  bool _lowerDoorOpen = false;
  String _connectionStatus = 'Disconnected';

  // LED states
  bool _upperLedOn = false;
  bool _lowerLedOn = false;

  // Linked cabinet info
  String? _linkedCabinetId;
  String? _linkedCabinetName;
  StreamSubscription<Map<String, dynamic>>? _doorSubscription;
  StreamSubscription<String>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    final iotService = context.read<IoTService>();
    _selectedDeviceId =
        iotService.connectedDeviceId ?? iotService.preferredDeviceId;
    _connectionStatus = iotService.isConnected
        ? 'Connected'
        : (iotService.isReconnecting ? 'Reconnecting' : 'Disconnected');
    _listenToIoTEvents();
    _loadLinkedCabinet();
  }

  @override
  void dispose() {
    _doorSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  // ── Permission Check ──────────────────────────────
  Future<bool> _checkPermissions() async {
    // Check location permission
    final status = await Permission.locationWhenInUse.status;

    if (status.isGranted) {
      // Also check Bluetooth permissions for Android 12+
      if (await _checkBluetoothPermissions()) {
        return true;
      }
      return false;
    }

    if (status.isDenied) {
      final result = await Permission.locationWhenInUse.request();
      if (result.isGranted) {
        return await _checkBluetoothPermissions();
      }
      return false;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<bool> _checkBluetoothPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.status;
    final bluetoothConnect = await Permission.bluetoothConnect.status;

    if (!bluetoothScan.isGranted) {
      final result = await Permission.bluetoothScan.request();
      if (!result.isGranted) return false;
    }

    if (!bluetoothConnect.isGranted) {
      final result = await Permission.bluetoothConnect.request();
      if (!result.isGranted) return false;
    }

    return true;
  }

  // ── Load linked cabinet ────────────────────────────
  Future<void> _loadLinkedCabinet() async {
    final iotService = context.read<IoTService>();
    final deviceId = iotService.connectedDeviceId;

    if (deviceId != null) {
      final cabProvider = context.read<CabinetProvider>();
      if (cabProvider.cabinets.isEmpty) {
        await cabProvider.forceLoadCabinets();
      }

      try {
        final cabinet = cabProvider.cabinets.firstWhere(
          (c) => c.bleDeviceId == deviceId,
        );
        setState(() {
          _linkedCabinetId = cabinet.id;
          _linkedCabinetName = cabinet.name;
        });
        debugPrint('🔗 Found linked cabinet: ${cabinet.name}');
      } catch (_) {
        setState(() {
          _linkedCabinetId = null;
          _linkedCabinetName = null;
        });
        debugPrint('⚠️ No cabinet linked to this device');
      }
    }
  }

  void _listenToIoTEvents() {
    final iotService = context.read<IoTService>();

    _doorSubscription = iotService.doorEvents.listen((event) {
      if (!mounted) return;
      final door = event['door'] as String? ?? '';
      final isOpen = event['isOpen'] as bool? ?? false;

      setState(() {
        if (door == 'upper') {
          _upperDoorOpen = isOpen;
          // ✅ Turn off light when door closes
          if (!isOpen && _upperLedOn) {
            _upperLedOn = false;
            iotService.sendLEDCommand(CabinetDoor.upper, false);
          }
        } else if (door == 'lower') {
          _lowerDoorOpen = isOpen;
          // ✅ Turn off light when door closes
          if (!isOpen && _lowerLedOn) {
            _lowerLedOn = false;
            iotService.sendLEDCommand(CabinetDoor.lower, false);
          }
        }
      });

      if (door == 'upper') {
        _showDoorNotification('Upper Door', isOpen);
      } else if (door == 'lower') {
        _showDoorNotification('Lower Door', isOpen);
      }
    });

    _connectionSubscription = iotService.connectionStatus.listen((status) {
      if (!mounted) return;
      setState(() => _connectionStatus = status);

      if (status == 'Connected') {
        _loadLinkedCabinet();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Connected to cabinet!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (status == 'Disconnected' && !iotService.isReconnecting) {
        setState(() {
          _linkedCabinetId = null;
          _linkedCabinetName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔴 Disconnected from cabinet'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _showDoorNotification(String doorName, bool isOpen) {
    final message = isOpen ? '🔓 $doorName opened' : '🔒 $doorName closed';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isOpen ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Scan ──────────────────────────────────────────
  Future<void> _startScan() async {
    // ✅ Check permissions first
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Location and Bluetooth permissions are required for BLE scanning.\n'
            'Please grant permissions in settings.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
      _connectionStatus = 'Scanning...';
    });

    final iotService = context.read<IoTService>();

    try {
      await iotService.startScan();
      await Future.delayed(const Duration(seconds: 10));

      setState(() {
        _devices = List.from(iotService.discoveredDevices);
        _isScanning = false;
        _connectionStatus =
            _devices.isEmpty ? 'No devices found' : 'Devices found';
      });

      if (_devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No devices found.\n\n'
              'Make sure:\n'
              '1. ESP32 is powered on (LED blinking)\n'
              '2. Bluetooth is enabled on your phone\n'
              '3. ESP32 is in range (within 10 meters)\n'
              '4. ESP32 firmware is running',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Found ${_devices.length} device(s)! Tap Connect.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _connectionStatus = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Connect ────────────────────────────────────────
  Future<void> _connectToDevice(String deviceId) async {
    setState(() {
      _isConnecting = true;
      _selectedDeviceId = deviceId;
    });

    final iotService = context.read<IoTService>();
    final success = await iotService.connectToDevice(deviceId);

    if (!mounted) return;
    setState(() => _isConnecting = false);

    if (success) {
      await _loadLinkedCabinet();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Connected to ESP32!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to connect to device'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final iotService = context.read<IoTService>();
    await iotService.disconnect();
    if (!mounted) return;
    setState(() {
      _selectedDeviceId = null;
      _upperDoorOpen = false;
      _lowerDoorOpen = false;
      _upperLedOn = false;
      _lowerLedOn = false;
      _linkedCabinetId = null;
      _linkedCabinetName = null;
    });
  }

  // ── Door Controls ─────────────────────────────────
  Future<void> _toggleDoor(String door) async {
    final iotService = context.read<IoTService>();

    try {
      if (door == 'upper') {
        if (_upperDoorOpen) {
          await iotService.closeDoor(CabinetDoor.upper);
        } else {
          await iotService.openDoor(CabinetDoor.upper);
        }
      } else if (door == 'lower') {
        if (_lowerDoorOpen) {
          await iotService.closeDoor(CabinetDoor.lower);
        } else {
          await iotService.openDoor(CabinetDoor.lower);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openBothDoors() async {
    final iotService = context.read<IoTService>();
    try {
      await iotService.openBothDoors();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _closeBothDoors() async {
    final iotService = context.read<IoTService>();
    try {
      await iotService.closeBothDoors();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleLED(String door) async {
    final iotService = context.read<IoTService>();

    try {
      if (door == 'upper') {
        _upperLedOn = !_upperLedOn;
        await iotService.sendLEDCommand(CabinetDoor.upper, _upperLedOn);
      } else if (door == 'lower') {
        _lowerLedOn = !_lowerLedOn;
        await iotService.sendLEDCommand(CabinetDoor.lower, _lowerLedOn);
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Navigation ────────────────────────────────────
  void _goToAddItem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(
          presetCabinetId: _linkedCabinetId,
        ),
      ),
    );
  }

  void _goToCabinetDetail() {
    if (_linkedCabinetId != null) {
      Navigator.pushNamed(
        context,
        '/cabinet-detail',
        arguments: _linkedCabinetId,
      );
    }
  }

  // ── Build ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final iotService = context.watch<IoTService>();
    final isConnected = iotService.isConnected;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Cabinet Control'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatus(isConnected, textColor, subColor),
            const SizedBox(height: 16),
            if (isConnected && _linkedCabinetId != null)
              _buildLinkedCabinetInfo(textColor, subColor, isDark),
            const SizedBox(height: 20),
            if (!isConnected) ...[
              _buildSavedCabinets(textColor, subColor),
              const SizedBox(height: 16),
              _buildScanSection(textColor, subColor),
            ],
            if (isConnected) ...[
              const SizedBox(height: 16),
              _buildControlSection(textColor, subColor, isDark),
            ],
            if (isConnected) ...[
              const SizedBox(height: 20),
              _buildQuickActions(textColor, isDark),
            ],
            if (isConnected) ...[
              const SizedBox(height: 24),
              _buildItemsSection(),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Widget Builders ────────────────────────────────
  Widget _buildSavedCabinets(Color textColor, Color subColor) {
    final linkedCabinets = context
        .watch<CabinetProvider>()
        .accessibleCabinets
        .where((cabinet) => cabinet.isLinkedToDevice)
        .toList();

    if (linkedCabinets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My BLE Cabinets',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        ...linkedCabinets.map((cabinet) {
          final deviceId = cabinet.bleDeviceId!;
          final isTrying = _selectedDeviceId == deviceId &&
              (_isConnecting || _connectionStatus == 'Reconnecting');
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.kitchen, color: Color(0xFF4ECDC4)),
              title: Text(cabinet.name, style: TextStyle(color: textColor)),
              subtitle: Text(
                cabinet.location?.isNotEmpty == true
                    ? cabinet.location!
                    : deviceId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subColor),
              ),
              trailing: isTrying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      onPressed: () => _connectToDevice(deviceId),
                      child: const Text('Connect'),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConnectionStatus(
      bool isConnected, Color textColor, Color subColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green
                    : (_connectionStatus == 'Reconnecting'
                        ? Colors.orange
                        : Colors.red),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'Connected' : _connectionStatus,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isConnected
                          ? Colors.green
                          : (_connectionStatus == 'Reconnecting'
                              ? Colors.orange
                              : Colors.red),
                    ),
                  ),
                  Text(
                    isConnected
                        ? 'ESP32 Device'
                        : (_connectionStatus == 'Reconnecting'
                            ? 'Trying the last cabinet automatically'
                            : 'No device connected'),
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            ),
            if (isConnected)
              const Icon(Icons.bluetooth_connected, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedCabinetInfo(Color textColor, Color subColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: Color(0xFF4ECDC4), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linked Cabinet',
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _linkedCabinetName ?? 'Unknown Cabinet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF4ECDC4)),
            onPressed: _goToCabinetDetail,
            tooltip: 'View Cabinet',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Color textColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.add_box_outlined,
                label: 'Add Item',
                description: _linkedCabinetName != null
                    ? 'To ${_linkedCabinetName!}'
                    : 'To cabinet',
                color: const Color(0xFF4ECDC4),
                onTap: _goToAddItem,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionCard(
                icon: Icons.inventory_2_outlined,
                label: 'View Items',
                description: 'In this cabinet',
                color: const Color(0xFF45B7D1),
                onTap: _goToCabinetDetail,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanSection(Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_connectionStatus != 'Disconnected' &&
            _connectionStatus != 'Connected')
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _connectionStatus.contains('error')
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _connectionStatus.contains('error')
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _connectionStatus.contains('error')
                      ? Icons.error_outline
                      : Icons.info_outline,
                  color: _connectionStatus.contains('error')
                      ? Colors.red
                      : Colors.blue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectionStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _connectionStatus.contains('error')
                          ? Colors.red
                          : textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_devices.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${_devices.length} device(s):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              ..._devices
                  .map((device) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.devices,
                              color: Color(0xFF4ECDC4)),
                          title: Text(
                            device.name.isNotEmpty
                                ? device.name
                                : 'ESP32 Device',
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: Text(
                            device.id,
                            style: TextStyle(fontSize: 11, color: subColor),
                          ),
                          trailing: _isConnecting &&
                                  _selectedDeviceId == device.id
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  onPressed: () => _connectToDevice(device.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4ECDC4),
                                    minimumSize: const Size(70, 30),
                                  ),
                                  child: const Text('Connect'),
                                ),
                        ),
                      ))
                  .toList(),
            ],
          ),
        if (_devices.isEmpty &&
            !_isScanning &&
            _connectionStatus != 'Scanning...')
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 60,
                    color: subColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No devices found.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Scan for Devices" to search.\n'
                    'Make sure ESP32 is powered on and in range.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlSection(Color textColor, Color subColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cabinet Controls',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildDoorControl(
          title: 'Upper Door',
          icon: Icons.arrow_upward,
          isOpen: _upperDoorOpen,
          ledOn: _upperLedOn,
          onToggleDoor: () => _toggleDoor('upper'),
          onToggleLED: () => _toggleLED('upper'),
          color: const Color(0xFF4ECDC4),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildDoorControl(
          title: 'Lower Door',
          icon: Icons.arrow_downward,
          isOpen: _lowerDoorOpen,
          ledOn: _lowerLedOn,
          onToggleDoor: () => _toggleDoor('lower'),
          onToggleLED: () => _toggleLED('lower'),
          color: const Color(0xFFFF6B6B),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openBothDoors,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Both'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4ECDC4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _closeBothDoors,
                icon: const Icon(Icons.close),
                label: const Text('Close Both'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _toggleLED('upper');
                  Future.delayed(const Duration(milliseconds: 200), () {
                    _toggleLED('lower');
                  });
                },
                icon: Icon(
                    _upperLedOn ? Icons.lightbulb : Icons.lightbulb_outline),
                label: Text(_upperLedOn ? 'LED On' : 'LED Off'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: _upperLedOn ? Colors.amber : Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoorControl({
    required String title,
    required IconData icon,
    required bool isOpen,
    required bool ledOn,
    required VoidCallback onToggleDoor,
    required VoidCallback onToggleLED,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isOpen ? Icons.lock_open : Icons.lock,
                color: isOpen ? Colors.green : Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    isOpen ? '🟢 Open' : '🔴 Closed',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOpen ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                ledOn ? Icons.lightbulb : Icons.lightbulb_outline,
                color: ledOn ? Colors.amber : Colors.grey,
              ),
              onPressed: onToggleLED,
              tooltip: 'Toggle LED',
            ),
            ElevatedButton(
              onPressed: onToggleDoor,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOpen ? Colors.red : const Color(0xFF4ECDC4),
                minimumSize: const Size(70, 36),
              ),
              child: Text(isOpen ? 'Close' : 'Open'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    final itemProvider = context.watch<ItemProvider>();
    final items = itemProvider.items;

    final cabinetItems = items
        .where((item) => item.cabinetId != null && item.cabinetId!.isNotEmpty)
        .toList();

    if (cabinetItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📦 Items in Cabinet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No items in this cabinet'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📦 Items in Cabinet (${cabinetItems.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...cabinetItems.map((item) => ListTile(
              leading:
                  Text(item.icon ?? '📦', style: const TextStyle(fontSize: 24)),
              title: Text(item.name),
              subtitle: Text('Qty: ${item.quantity} ${item.unit}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isLowStock ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.isLowStock ? 'Low Stock' : 'In Stock',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
