import 'package:flutter/material.dart';
import 'dart:io'; // Added for File
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_model.dart';
import '../providers/cabinet_provider.dart';

class AddEditCabinetScreen extends StatefulWidget {
  final CabinetModel? cabinet;

  const AddEditCabinetScreen({super.key, this.cabinet});

  @override
  State<AddEditCabinetScreen> createState() => _AddEditCabinetScreenState();
}

class _AddEditCabinetScreenState extends State<AddEditCabinetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedIcon;
  String? _selectedColor;
  bool _isFavorite = false;
  bool _isLoading = false;
  XFile? _imageFile;

  final List<String> _icons = ['🗄️', '📦', '🏠', '🛋️', '🚪', '🪑', '🛏️', '🧺'];
  final List<String> _locations = [
    'Living Room', 'Kitchen', 'Bedroom', 'Bathroom', 'Garage',
    'Office', 'Storage', 'Pantry', 'Closet', 'Other'
  ];
  final List<String> _colors = [
    '#FF6B6B', '#FFA94D', '#FDCB6E', '#00B894',
    '#4ECDC4', '#45B7D1', '#6C5CE7', '#A29BFE',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.cabinet != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final cabinet = widget.cabinet!;
    _nameController.text = cabinet.name;
    _locationController.text = cabinet.location ?? '';
    _descriptionController.text = cabinet.description ?? '';
    _selectedIcon = cabinet.icon;
    _selectedColor = cabinet.color;
    _isFavorite = cabinet.isFavorite;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _saveCabinet() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final cabinet = CabinetModel(
        id: widget.cabinet?.id,
        name: _nameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
        photoUrl: null, // Upload image if needed
        isFavorite: _isFavorite,
        createdAt: widget.cabinet?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        userId: '',
      );
      
      if (widget.cabinet == null) {
        await context.read<CabinetProvider>().addCabinet(cabinet);
      } else {
        await context.read<CabinetProvider>().updateCabinet(cabinet);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2FFFF),
        elevation: 0,
        title: Text(
          widget.cabinet == null ? 'Add Cabinet' : 'Edit Cabinet',
          style: const TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveCabinet,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF4ECDC4),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_imageFile!.path), // Fixed: File is now recognized
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add cabinet photo',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Icon and Color
              Row(
                children: [
                  Expanded(
                    child: _buildIconPicker(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildColorPicker(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Cabinet Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cabin),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter cabinet name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Location
              DropdownButtonFormField<String>(
                value: _locationController.text.isEmpty ? null : _locationController.text,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select Location'),
                  ),
                  ..._locations.map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _locationController.text = value ?? '';
                  });
                },
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Favorite toggle
              Row(
                children: [
                  const Text(
                    'Mark as Favorite',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isFavorite,
                    onChanged: (value) {
                      setState(() {
                        _isFavorite = value;
                      });
                    },
                    activeThumbColor: const Color(0xFF4ECDC4), // Fixed deprecated activeColor
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save button
              if (!_isLoading)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveCabinet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.cabinet == null ? 'Add Cabinet' : 'Update Cabinet',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return DropdownButtonFormField<String>(
      value: _selectedIcon,
      decoration: const InputDecoration(
        labelText: 'Icon',
        border: OutlineInputBorder(),
      ),
      items: _icons.map((icon) {
        return DropdownMenuItem(
          value: icon,
          child: Text(icon, style: const TextStyle(fontSize: 24)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedIcon = value;
        });
      },
      // Fixed: using selectedItemBuilder instead of deprecated value
      selectedItemBuilder: (context) {
        return _icons.map((icon) {
          return Center(
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          );
        }).toList();
      },
    );
  }

  Widget _buildColorPicker() {
    return DropdownButtonFormField<String>(
      value: _selectedColor,
      decoration: const InputDecoration(
        labelText: 'Color',
        border: OutlineInputBorder(),
      ),
      items: _colors.map((color) {
        return DropdownMenuItem(
          value: color,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 8),
              Text(color),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedColor = value;
        });
      },
      // Fixed: using selectedItemBuilder instead of deprecated value
      selectedItemBuilder: (context) {
        return _colors.map((color) {
          return Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 8),
              Text(color),
            ],
          );
        }).toList();
      },
    );
  }
}