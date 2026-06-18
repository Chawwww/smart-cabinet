import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Removed unused import: 'dart:io' - not needed in this file
import '../models/box_model.dart';
import '../providers/cabinet_provider.dart';

class AddEditBoxScreen extends StatefulWidget {
  final BoxModel? box;
  final String? cabinetId;

  const AddEditBoxScreen({super.key, this.box, this.cabinetId});

  @override
  State<AddEditBoxScreen> createState() => _AddEditBoxScreenState();
}

class _AddEditBoxScreenState extends State<AddEditBoxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  
  String? _selectedCabinetId;
  String? _selectedType;
  String? _selectedIcon;
  String? _selectedColor;
  bool _isLoading = false;

  final List<String> _types = ['Drawer', 'Shelf', 'Container', 'Hook', 'Tray'];
  final List<String> _icons = ['📦', '🗄️', '📁', '🧺', '🪣', '📊', '🗂️'];
  final List<String> _colors = [
    '#FF6B6B', '#FFA94D', '#FDCB6E', '#00B894',
    '#4ECDC4', '#45B7D1', '#6C5CE7', '#A29BFE',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.box != null) {
      _populateFields();
    } else {
      _selectedCabinetId = widget.cabinetId;
    }
    // Load cabinets for dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CabinetProvider>().loadCabinets();
    });
  }

  void _populateFields() {
    final box = widget.box!;
    _nameController.text = box.name;
    _descriptionController.text = box.description ?? '';
    _selectedCabinetId = box.cabinetId;
    _selectedType = box.type;
    _selectedIcon = box.icon;
    _selectedColor = box.color;
    _capacityController.text = box.capacity?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _saveBox() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final box = BoxModel(
        id: widget.box?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        cabinetId: _selectedCabinetId!,
        type: _selectedType ?? 'Drawer',
        icon: _selectedIcon,
        color: _selectedColor,
        capacity: _capacityController.text.trim().isEmpty
            ? null
            : int.parse(_capacityController.text),
        createdAt: widget.box?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        userId: '',
      );
      
      if (widget.box == null) {
        await context.read<CabinetProvider>().addBox(box);
      } else {
        await context.read<CabinetProvider>().updateBox(box);
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
    final cabinets = context.watch<CabinetProvider>().cabinets;

    return Scaffold(
      backgroundColor: const Color(0xFFF2FFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2FFFF),
        elevation: 0,
        title: Text(
          widget.box == null ? 'Add Box' : 'Edit Box',
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
              onPressed: _saveBox,
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

              // Basic Information
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Box Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter box name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Cabinet
              DropdownButtonFormField<String>(
                value: _selectedCabinetId,
                decoration: const InputDecoration(
                  labelText: 'Cabinet *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select Cabinet'),
                  ),
                  ...cabinets.map((cabinet) {
                    return DropdownMenuItem(
                      value: cabinet.id,
                      child: Text(cabinet.name),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCabinetId = value;
                  });
                },
                validator: (value) {
                  if (value == null) return 'Please select a cabinet';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Box Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Box Type',
                  border: OutlineInputBorder(),
                ),
                items: _types.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Capacity
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (int.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save button
              if (!_isLoading)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveBox,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.box == null ? 'Add Box' : 'Update Box',
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