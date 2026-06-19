import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/box_model.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';

class AddEditBoxScreen extends StatefulWidget {
  final BoxModel? box;
  final String? cabinetId;

  const AddEditBoxScreen({super.key, this.box, this.cabinetId});

  @override
  State<AddEditBoxScreen> createState() => _AddEditBoxScreenState();
}

class _AddEditBoxScreenState extends State<AddEditBoxScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _nameController       = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController   = TextEditingController();

  String? _selectedCabinetId;
  String? _selectedType;
  String? _selectedIcon;
  String? _selectedColor;
  bool _isLoading = false;

  final List<String> _types  = ['Drawer','Shelf','Container','Hook','Tray','Bin'];
  final List<String> _icons  = ['📦','🗄️','📁','🧺','🪣','📊','🗂️','📂'];
  final List<String> _colors = [
    '#FF6B6B','#FFA94D','#FDCB6E','#00B894',
    '#4ECDC4','#45B7D1','#6C5CE7','#A29BFE',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.box != null) {
      final b = widget.box!;
      _nameController.text        = b.name;
      _descriptionController.text = b.description ?? '';
      _selectedCabinetId          = b.cabinetId;
      _selectedType               = b.type;
      _selectedIcon               = b.icon;
      _selectedColor              = b.color;
      _capacityController.text    = b.capacity?.toString() ?? '';
    } else {
      _selectedCabinetId = widget.cabinetId;
      _selectedType  = _types.first;
      _selectedIcon  = _icons.first;
      _selectedColor = _colors[4];
    }
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CabinetProvider>().loadCabinets());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCabinetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a cabinet')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthProvider>().currentUser?.id ?? '';
      final box = BoxModel(
        id:          widget.box?.id,
        name:        _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        cabinetId:   _selectedCabinetId!,
        type:        _selectedType ?? 'Drawer',
        icon:        _selectedIcon,
        color:       _selectedColor,
        capacity:    _capacityController.text.trim().isEmpty
            ? null
            : int.tryParse(_capacityController.text),
        createdAt:   widget.box?.createdAt ?? DateTime.now(),
        updatedAt:   DateTime.now(),
        userId:      userId,
      );
      if (widget.box == null) {
        await context.read<CabinetProvider>().addBox(box);
      } else {
        await context.read<CabinetProvider>().updateBox(box);
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
    final cabinets  = context.watch<CabinetProvider>().cabinets;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

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
        title: Text(widget.box == null ? 'Add Box / Shelf' : 'Edit Box / Shelf'),
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
              // Preview
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: previewColor
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedIcon ?? '📦',
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Text(
                        _nameController.text.isEmpty
                            ? 'Box / Shelf Name'
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

              // Icon + Color
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _icons.map((icon) {
                            final sel = _selectedIcon == icon;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedIcon = icon),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: sel
                                      ? const Color(0xFF4ECDC4)
                                          .withValues(alpha: 0.2)
                                      : (isDark
                                          ? const Color(0xFF2D2D2D)
                                          : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: sel
                                        ? const Color(0xFF4ECDC4)
                                        : (isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300),
                                    width: sel ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(icon,
                                      style:
                                          const TextStyle(fontSize: 22)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Color
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
                                width: 34, height: 34,
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
                                        color: Colors.white, size: 16)
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
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Box / Shelf Name *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),

              // Cabinet dropdown
              DropdownButtonFormField<String>(
                value: _selectedCabinetId,
                decoration: const InputDecoration(
                  labelText: 'Cabinet *',
                  prefixIcon: Icon(Icons.cabin),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Select cabinet')),
                  ...cabinets.map((cab) =>
                      DropdownMenuItem(value: cab.id, child: Text(cab.name))),
                ],
                onChanged: (v) => setState(() => _selectedCabinetId = v),
                validator: (v) =>
                    v == null ? 'Please select a cabinet' : null,
              ),
              const SizedBox(height: 12),

              // Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _types.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedType = v),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Capacity
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity (optional)',
                  prefixIcon: Icon(Icons.numbers),
                  hintText: 'Max number of items',
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                    return 'Must be a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: Text(
                    widget.box == null ? 'Add Box' : 'Update Box',
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