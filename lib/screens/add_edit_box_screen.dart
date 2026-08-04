import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/box_model.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../services/iot_service.dart';
import '../config/app_constants.dart';

class AddEditBoxScreen extends StatefulWidget {
  final BoxModel? box;
  final String? presetCabinetId;
  const AddEditBoxScreen({super.key, this.box, this.presetCabinetId});

  @override
  State<AddEditBoxScreen> createState() => _AddEditBoxScreenState();
}

class _AddEditBoxScreenState extends State<AddEditBoxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();

  String? _cabinetId;
  String _type = 'Drawer';
  String? _selectedIcon;
  String? _selectedColor;
  String? _doorId;
  bool _isLoading = false;

  bool get _isEditing => widget.box != null;

  static const _types = ['Drawer', 'Shelf', 'Container', 'Box', 'Bin', 'Other'];

  final List<String> _icons = [
    '📦', '🗃️', '🧰', '🪣', '📁', '🧴', '🥫', '🧊',
    '📚', '🧺', '🧯', '🧻', '🪛', '🧪', '💊', '🍫',
    '📋', '📊', '📏', '📐', '🔧', '🔨', '🪚', '🧹',
  ];

  final List<String> _colors = [
    '#FF6B6B', '#FFA94D', '#FDCB6E', '#00B894',
    '#4ECDC4', '#45B7D1', '#6C5CE7', '#A29BFE',
    '#FD79A8', '#E17055', '#00CEC9', '#0984E3',
  ];

  final List<Map<String, dynamic>> _doorOptions = const [
    {'label': 'Not linked to a door', 'value': null},
    {'label': 'Upper Door', 'value': 'upper'},
    {'label': 'Lower Door', 'value': 'lower'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final b = widget.box!;
      _nameController.text = b.name;
      _descriptionController.text = b.description ?? '';
      _capacityController.text = b.capacity?.toString() ?? '';
      _cabinetId = b.cabinetId;
      _type = b.type;
      _selectedIcon = b.icon;
      _selectedColor = b.color;
      _doorId = b.doorId;
    } else {
      _cabinetId = widget.presetCabinetId;
      _selectedIcon = _icons.first;
      _selectedColor = _colors[4];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CabinetProvider>().loadCabinets();
    });
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
    if (_cabinetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a cabinet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthProvider>().currentUser?.id ?? '';
      final existing = widget.box;

      final box = BoxModel(
        id: existing?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        cabinetId: _cabinetId!,
        type: _type,
        icon: _selectedIcon,
        color: _selectedColor,
        capacity: _capacityController.text.trim().isEmpty
            ? null
            : int.tryParse(_capacityController.text.trim()),
        doorId: _doorId,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        userId: existing?.userId ?? userId,
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDoorSection(Color textColor, Color subColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: (_doorId != null ? Colors.green : const Color(0xFF4ECDC4))
            .withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (_doorId != null ? Colors.green : const Color(0xFF4ECDC4))
              .withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              _doorId != null ? Icons.sensor_door : Icons.sensor_door_outlined,
              size: 16,
              color: _doorId != null ? Colors.green : const Color(0xFF4ECDC4),
            ),
            const SizedBox(width: 8),
            Text('Smart Door (optional)',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Link this box to a physical door on your smart cabinet to enable '
            'live open/close and light controls from the item screen.',
            style: TextStyle(fontSize: 11, color: subColor),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _doorId,
            decoration: InputDecoration(
              labelText: 'Door',
              filled: true,
              fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            items: _doorOptions.map((opt) {
              final label = opt['label'] as String;
              final value = opt['value'] as String?;
              return DropdownMenuItem(
                value: value,
                child: Row(
                  children: [
                    Icon(
                      value == 'upper'
                          ? Icons.arrow_upward
                          : value == 'lower'
                              ? Icons.arrow_downward
                              : Icons.block,
                      size: 16,
                      color: value == _doorId
                          ? const Color(0xFF4ECDC4)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _doorId = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cabProvider = context.watch<CabinetProvider>();
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = textColor.withValues(alpha: 0.55);

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF4ECDC4), width: 1.5)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.box == null ? 'Add Box' : 'Edit Box'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF4ECDC4))))
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
              // ── Icon picker ──────────────────────────────
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
                  color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _icons.length,
                  itemBuilder: (_, i) {
                    final icon = _icons[i];
                    final sel = _selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF4ECDC4).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: sel
                              ? Border.all(
                                  color: const Color(0xFF4ECDC4), width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(icon,
                              style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Color picker ──────────────────────────────
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
                    col = Color(int.parse(c.replaceFirst('#', '0xFF')));
                  } catch (_) {
                    col = Colors.grey;
                  }
                  final sel = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: sel ? Border.all(color: textColor, width: 3) : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Name ──────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: deco('Box Name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),

              // ── Cabinet ──────────────────────────────────
              DropdownButtonFormField<String>(
                value: _cabinetId,
                decoration: deco('Cabinet *'),
                items: cabProvider.cabinets
                    .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Text(c.icon ?? '🗄️'),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        )))
                    .toList(),
                onChanged: (v) => setState(() => _cabinetId = v),
                validator: (v) => v == null ? 'Please select a cabinet' : null,
              ),
              const SizedBox(height: 12),

              // ── Type ──────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _type,
                decoration: deco('Type'),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),

              // ── Capacity ──────────────────────────────────
              TextFormField(
                controller: _capacityController,
                decoration: deco('Capacity (optional)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return int.tryParse(v.trim()) == null
                      ? 'Must be a number'
                      : null;
                },
              ),
              const SizedBox(height: 12),

              // ── Description ───────────────────────────────
              TextFormField(
                controller: _descriptionController,
                decoration: deco('Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 4),

              // ── Smart Door section ───────────────────────
              _buildDoorSection(textColor, subColor, isDark),

              // ── Save Button ──────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(
                    widget.box == null ? 'Add Box' : 'Update Box',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}