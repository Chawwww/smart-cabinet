import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_model.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';

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
    } else {
      _selectedIcon  = _icons.first;
      _selectedColor = _colors[4];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
      final cabinet = CabinetModel(
        id:          widget.cabinet?.id,
        name:        _nameController.text.trim(),
        location:    _selectedLocation,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        icon:        _selectedIcon,
        color:       _selectedColor,
        photoUrl:    null,
        isFavorite:  _isFavorite,
        createdAt:   widget.cabinet?.createdAt ?? DateTime.now(),
        updatedAt:   DateTime.now(),
        userId:      userId,
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

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
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