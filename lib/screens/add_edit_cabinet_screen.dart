import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_model.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../services/iot_service.dart'; // ✅ ADDED

class AddEditCabinetScreen extends StatefulWidget {
  final CabinetModel? cabinet;
  const AddEditCabinetScreen({super.key, this.cabinet});

  @override
  State<AddEditCabinetScreen> createState() => _AddEditCabinetScreenState();
}

class _AddEditCabinetScreenState extends State<AddEditCabinetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedIcon;
  String? _selectedColor;
  String? _selectedLocation;
  bool _isFavorite = false;
  bool _isLoading  = false;
  XFile? _imageFile;

  // ✅ ADDED — BLE device link state
  String? _bleDeviceId;
  bool _bleConnected = false;
  String? _connectedDeviceId;
  StreamSubscription<String>? _connSub;

  final List<String> _icons = [
    '🗄️','📦','🏠','🛋️','🚪','🪑','🛏️','🧺',
    '🏪','🏥','🧰','🪣','🗃️','📁','🏷️','🔒',
  ];
  final List<String> _locations = [
    'Living Room','Kitchen','Bedroom','Bathroom',
    'Garage','Office','Storage','Pantry','Closet','Other',
  ];
  final List<String> _colors = [
    '#FF6B6B','#FFA94D','#FDCB6E','#00B894',
    '#4ECDC4','#45B7D1','#6C5CE7','#A29BFE',
    '#FD79A8','#E17055','#00CEC9','#0984E3',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.cabinet != null) {
      final c = widget.cabinet!;
      _nameController.text        = c.name;
      _descriptionController.text = c.description ?? '';
      _selectedIcon               = c.icon;
      _selectedColor              = c.color;
      _selectedLocation           = c.location;
      _isFavorite                 = c.isFavorite;
      _bleDeviceId                = c.bleDeviceId; // ✅ ADDED
    } else {
      _selectedIcon  = _icons.first;
      _selectedColor = _colors[4];
    }

    // ✅ ADDED — track live BLE connection so we can offer "Link this device"
    _bleConnected = IoTService().isConnected;
    _connectedDeviceId = IoTService().connectedDeviceId;
    _connSub = IoTService().connectionStatus.listen((status) {
      if (!mounted) return;
      setState(() {
        _bleConnected = status == 'Connected';
        _connectedDeviceId = IoTService().connectedDeviceId;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _connSub?.cancel(); // ✅ ADDED
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthProvider>().currentUser?.id ?? '';
      final existing = widget.cabinet;

      final cabinet = CabinetModel(
        id:           existing?.id,
        name:         _nameController.text.trim(),
        location:     _selectedLocation,
        description:  _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        icon:         _selectedIcon,
        color:        _selectedColor,
        photoUrl:     existing?.photoUrl, // ✅ preserved — this form doesn't set it
        isFavorite:   _isFavorite,
        itemCount:    existing?.itemCount ?? 0,          // ✅ FIX — don't reset on edit
        boxCount:     existing?.boxCount ?? 0,           // ✅ FIX — don't reset on edit
        sharedWith:   existing?.sharedWith ?? const [],  // ✅ FIX — don't wipe sharing
        permissions:  existing?.permissions ?? const {}, // ✅ FIX — don't wipe sharing
        bleDeviceId:  _bleDeviceId,                      // ✅ ADDED
        createdAt:    existing?.createdAt ?? DateTime.now(),
        updatedAt:    DateTime.now(),
        userId:       existing?.userId ?? userId, // ✅ preserve original owner on edit
      );
      if (widget.cabinet == null) {
        await context.read<CabinetProvider>().addCabinet(cabinet);
      } else {
        await context.read<CabinetProvider>().updateCabinet(cabinet);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ ADDED — link/unlink section
  Widget _buildDeviceLinkSection(Color textColor, Color subColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: (_bleDeviceId != null ? Colors.green : const Color(0xFF4ECDC4))
            .withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (_bleDeviceId != null ? Colors.green : const Color(0xFF4ECDC4))
                .withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              _bleDeviceId != null
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_outlined,
              size: 16,
              color: _bleDeviceId != null ? Colors.green : const Color(0xFF4ECDC4),
            ),
            const SizedBox(width: 8),
            Text('Smart Cabinet Device',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
          ]),
          const SizedBox(height: 8),

          if (_bleDeviceId != null) ...[
            Text(
              'Linked to device: ${_bleDeviceId!}',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _bleDeviceId = null),
                icon: const Icon(Icons.link_off, size: 16, color: Colors.red),
                label: const Text('Unlink device',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ] else if (_bleConnected && _connectedDeviceId != null) ...[
            Text(
              'Currently connected to $_connectedDeviceId — link it to this cabinet '
              'so the app recognizes it automatically next time you connect.',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _bleDeviceId = _connectedDeviceId),
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Link This Device'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4ECDC4)),
                ),
              ),
            ),
          ] else
            Text(
              'Not linked. Connect to a smart cabinet from Smart Cabinet Control, '
              'then come back here to link it — or save this cabinet now and link it later.',
              style: TextStyle(fontSize: 11, color: subColor),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final subColor  = textColor.withValues(alpha: 0.55); // ✅ ADDED
    final imageBg   = isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100;

    Color previewColor;
    try {
      previewColor = _selectedColor != null
          ? Color(int.parse(_selectedColor!.replaceFirst('#', '0xFF')))
          : const Color(0xFF4ECDC4);
    } catch (_) {
      previewColor = const Color(0xFF4ECDC4);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cabinet == null ? 'Add Cabinet' : 'Edit Cabinet'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4ECDC4)),
                  ))
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save',
                      style: TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: imageBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_imageFile!.path),
                              fit: BoxFit.cover))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 40,
                                color: isDark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('Tap to add cabinet photo',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Icon + Color row
              Row(
                children: [
                  // Icon picker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Icon',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                        const SizedBox(height: 8),
                        Container(
                          height: 100,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300),
                          ),
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: _icons.length,
                            itemBuilder: (_, i) {
                              final icon = _icons[i];
                              final sel = _selectedIcon == icon;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedIcon = icon),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? const Color(0xFF4ECDC4)
                                            .withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: sel
                                        ? Border.all(
                                            color: const Color(0xFF4ECDC4),
                                            width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(icon,
                                        style: const TextStyle(fontSize: 20)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Color picker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Color',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _colors.map((c) {
                            Color col;
                            try {
                              col = Color(
                                  int.parse(c.replaceFirst('#', '0xFF')));
                            } catch (_) {
                              col = Colors.grey;
                            }
                            final sel = _selectedColor == c;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = c),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: col,
                                  shape: BoxShape.circle,
                                  border: sel
                                      ? Border.all(
                                          color: textColor, width: 3)
                                      : null,
                                ),
                                child: sel
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 18)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Preview
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: previewColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedIcon ?? '🗄️',
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Text(
                        _nameController.text.isEmpty
                            ? 'Cabinet Name'
                            : _nameController.text,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cabinet Name *',
                  prefixIcon: Icon(Icons.cabin),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),

              // Location
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Select location')),
                  ..._locations.map((l) =>
                      DropdownMenuItem(value: l, child: Text(l))),
                ],
                onChanged: (v) => setState(() => _selectedLocation = v),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),

              // ✅ ADDED — Smart Cabinet Device link section
              _buildDeviceLinkSection(textColor, subColor, isDark),

              const SizedBox(height: 16),

              // Favourite
              Row(
                children: [
                  Icon(Icons.favorite_outline,
                      color: textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 12),
                  Text('Mark as Favourite',
                      style: TextStyle(fontSize: 16, color: textColor)),
                  const Spacer(),
                  Switch(
                    value: _isFavorite,
                    onChanged: (v) => setState(() => _isFavorite = v),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: Text(
                    widget.cabinet == null ? 'Add Cabinet' : 'Update Cabinet',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}