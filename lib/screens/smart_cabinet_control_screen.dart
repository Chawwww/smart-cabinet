// lib/screens/smart_cabinet_control_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../services/iot_service.dart';
import '../providers/auth_provider.dart';
import '../providers/item_provider.dart';
import '../widgets/loading_widget.dart';

class SmartCabinetControlScreen extends StatefulWidget {
  const SmartCabinetControlScreen({super.key});

  @override
  State<SmartCabinetControlScreen> createState() => _SmartCabinetControlScreenState();
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

  @override
  void initState() {
    super.initState();
    _listenToIoTEvents();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _listenToIoTEvents() {
    final iotService = context.read<IoTService>();
    
    // Listen to door events
    iotService.doorEvents.listen((event) {
      final door = event['door'] as String? ?? '';
      final isOpen = event['isOpen'] as bool? ?? false;
      
      setState(() {
        if (door == 'upper') {
          _upperDoorOpen = isOpen;
        } else if (door == 'lower') {
          _lowerDoorOpen = isOpen;
        }
      });
      
      // Show notification when door state changes
      if (door == 'upper') {
        _showDoorNotification('Upper Door', isOpen);
      } else if (door == 'lower') {
        _showDoorNotification('Lower Door', isOpen);
      }
    });
    
    // Listen to connection status
    iotService.connectionStatus.listen((status) {
      setState(() => _connectionStatus = status);
      
      if (status == 'Connected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Connected to cabinet!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (status == 'Disconnected') {
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
    final message = isOpen 
        ? '🔓 $doorName opened' 
        : '🔒 $doorName closed';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isOpen ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    final iotService = context.read<IoTService>();
    
    // Start scanning
    await iotService.startScan();
    
    // Listen for discovered devices
    await Future.delayed(const Duration(seconds: 5));
    
    setState(() {
      _devices = iotService.discoveredDevices;
      _isScanning = false;
    });

    if (_devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No devices found. Make sure ESP32 is powered on.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _connectToDevice(String deviceId) async {
    setState(() {
      _isConnecting = true;
      _selectedDeviceId = deviceId;
    });

    final iotService = context.read<IoTService>();
    final success = await iotService.connectToDevice(deviceId);

    setState(() => _isConnecting = false);

    if (success) {
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
    setState(() {
      _selectedDeviceId = null;
      _upperDoorOpen = false;
      _lowerDoorOpen = false;
      _upperLedOn = false;
      _lowerLedOn = false;
    });
  }

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
            // ── Connection Status ──────────────────────────
            _buildConnectionStatus(isConnected, textColor, subColor),

            const SizedBox(height: 20),

            // ── Scan / Connect Section ─────────────────────
            if (!isConnected)
              _buildScanSection(textColor, subColor),

            // ── Control Section ────────────────────────────
            if (isConnected) ...[
              const SizedBox(height: 16),
              _buildControlSection(textColor, subColor, isDark),
            ],

            // ── Items in Cabinet ──────────────────────────
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

  Widget _buildConnectionStatus(bool isConnected, Color textColor, Color subColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isConnected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  Text(
                    isConnected ? 'ESP32 Device' : 'No device connected',
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

  Widget _buildScanSection(Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20, height: 20,
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
              ..._devices.map((device) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Color(0xFF4ECDC4)),
                  title: Text(
                    device.name.isNotEmpty ? device.name : 'ESP32 Device',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    device.id,
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                  trailing: _isConnecting && _selectedDeviceId == device.id
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
              )).toList(),
            ],
          ),
        if (_devices.isEmpty && !_isScanning)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No devices found.\nTap "Scan for Devices" to search.\nMake sure ESP32 is powered on and in range.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subColor),
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

        // ── Upper Door ─────────────────────────────────────
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

        // ── Lower Door ─────────────────────────────────────
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

        // ── Both Doors ─────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _toggleDoor('upper');
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _toggleDoor('lower');
                  });
                },
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
                onPressed: () {
                  _toggleDoor('upper');
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _toggleDoor('lower');
                  });
                },
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

        // ── LED Control ────────────────────────────────────
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
                icon: Icon(_upperLedOn ? Icons.lightbulb : Icons.lightbulb_outline),
                label: Text(_upperLedOn ? 'LED On' : 'LED Off'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _upperLedOn ? Colors.amber : Colors.grey),
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
    
    // Filter items that have cabinetId matching current cabinet
    final cabinetItems = items.where((item) => 
      item.cabinetId != null && item.cabinetId!.isNotEmpty
    ).toList();

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
          leading: Text(item.icon ?? '📦', style: const TextStyle(fontSize: 24)),
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