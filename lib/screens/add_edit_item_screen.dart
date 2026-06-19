import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cabinet_provider.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import '../services/ai_service.dart';

class AddEditItemScreen extends StatefulWidget {
  final ItemModel? item;
  const AddEditItemScreen({super.key, this.item});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController        = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController       = TextEditingController();
  final _quantityController    = TextEditingController();
  final _lowStockController    = TextEditingController();
  final _noteController        = TextEditingController();
  final _tagsController        = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedCabinetId;
  String? _selectedBoxId;
  String  _unit   = 'pcs';
  String  _status = 'inside';

  DateTime? _expiryDate;
  DateTime? _productionDate;

  bool _isAiLoading = false;

  bool get _isEditing => widget.item != null;

  static const _units    = ['pcs','box','bottle','pack','kg','g','L','ml'];
  static const _statuses = ['inside','taken','used','damaged'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.item!;
      _nameController.text        = item.name;
      _descriptionController.text = item.description ?? '';
      _brandController.text       = item.brand ?? '';
      _quantityController.text    = item.quantity.toString();
      _lowStockController.text    = item.lowStockThreshold.toString();
      _noteController.text        = item.note ?? '';
      _tagsController.text        = item.tags.join(', ');
      _selectedCategoryId = item.categoryId;
      _selectedCabinetId  = item.cabinetId;   // can be null — that's fine
      _selectedBoxId      = item.boxId;
      _unit               = item.unit;
      _status             = item.status;
      _expiryDate         = item.expiryDate;
      _productionDate     = item.productionDate;
    } else {
      _quantityController.text = '1';
      _lowStockController.text = '5';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
      context.read<CabinetProvider>()
        ..loadCabinets()
        ..loadBoxes();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _quantityController.dispose();
    _lowStockController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // ── AI Category Suggest ───────────────────────────────
  Future<void> _suggestCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) { _showSnack('Enter an item name first'); return; }

    setState(() => _isAiLoading = true);
    try {
      final aiService = AIService()..initialize();
      final suggestion = await aiService.suggestCategory(name);
      final match = context.read<CategoryProvider>()
          .getCategoryByName(suggestion.trim());
      if (match != null) {
        setState(() => _selectedCategoryId = match.id);
        _showSnack('AI suggested: ${match.name}');
      } else {
        _showSnack('AI suggested "$suggestion" — no match found');
      }
    } catch (e) {
      _showSnack('AI suggestion failed: $e');
    } finally {
      setState(() => _isAiLoading = false);
    }
  }

  // ── Save ──────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Only category is required — location is optional
    if (_selectedCategoryId == null) {
      _showSnack('Please select a category');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final itemProvider = context.read<ItemProvider>();
    final now          = DateTime.now();

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final item = ItemModel(
      id:               widget.item?.id,
      name:             _nameController.text.trim(),
      description:      _descriptionController.text.trim().isEmpty
                            ? null : _descriptionController.text.trim(),
      categoryId:       _selectedCategoryId!,
      cabinetId:        _selectedCabinetId,   // nullable — saved as null if unset
      boxId:            _selectedBoxId,         // nullable — saved as null if unset
      brand:            _brandController.text.trim().isEmpty
                            ? null : _brandController.text.trim(),
      quantity:         int.tryParse(_quantityController.text) ?? 1,
      initialQuantity:  _isEditing
                            ? widget.item!.initialQuantity
                            : (int.tryParse(_quantityController.text) ?? 1),
      unit:             _unit,
      lowStockThreshold: int.tryParse(_lowStockController.text) ?? 5,
      expiryDate:       _expiryDate,
      productionDate:   _productionDate,
      status:           _status,
      note:             _noteController.text.trim().isEmpty
                            ? null : _noteController.text.trim(),
      tags:             tags,
      isFavorite:       widget.item?.isFavorite ?? false,
      takenCount:       widget.item?.takenCount ?? 0,
      createdAt:        widget.item?.createdAt ?? now,
      updatedAt:        now,
      userId:           authProvider.currentUser?.id ?? '',
    );

    if (_isEditing) {
      await itemProvider.updateItem(item);
    } else {
      await itemProvider.addItem(item);
    }

    if (itemProvider.error != null) {
      _showSnack('Error: ${itemProvider.error}');
    } else {
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ── Date pickers ──────────────────────────────────────
  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _pickProductionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _productionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _productionDate = picked);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── UI helpers ────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface)),
      );

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final cabinetProvider  = context.watch<CabinetProvider>();
    final itemProvider     = context.watch<ItemProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final boxes = _selectedCabinetId != null
        ? cabinetProvider.getBoxesForCabinet(_selectedCabinetId!)
        : cabinetProvider.boxes;

    // Theme-aware input decoration
    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
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
              borderSide:
                  const BorderSide(color: Color(0xFF4ECDC4), width: 1.5)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add Item'),
        actions: [
          if (itemProvider.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF4ECDC4))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Color(0xFF4ECDC4),
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [

            // ── Basic Info ─────────────────────────────
            _sectionTitle('Basic Info'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: deco('Item Name *', hint: 'e.g. Paracetamol'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                // AI suggest button
                Tooltip(
                  message: 'AI: Suggest Category',
                  child: InkWell(
                    onTap: _isAiLoading ? null : _suggestCategory,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 50,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFF4ECDC4).withValues(alpha: 0.5)),
                      ),
                      child: _isAiLoading
                          ? const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF4ECDC4))))
                          : const Icon(Icons.auto_awesome,
                              color: Color(0xFF4ECDC4)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _descriptionController,
                decoration: deco('Description', hint: 'Optional'),
                maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(
                controller: _brandController,
                decoration: deco('Brand', hint: 'Optional')),

            // ── Category (REQUIRED) ─────────────────────
            _sectionTitle('Category *'),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: deco('Category'),
              items: categoryProvider.categories.map((cat) {
                return DropdownMenuItem(
                  value: cat.id,
                  child: Row(children: [
                    Text(cat.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(cat.name),
                  ]),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
              hint: const Text('Select category'),
              validator: (v) => v == null ? 'Please select a category' : null,
            ),

            // ── Location (OPTIONAL) ─────────────────────
            _sectionTitle('Location (Optional)'),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF4ECDC4), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can skip location now and assign it later when your cabinet is set up.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),

            DropdownButtonFormField<String>(
              value: _selectedCabinetId,
              decoration: deco('Cabinet'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('No cabinet selected')),
                ...cabinetProvider.cabinets.map((cab) =>
                    DropdownMenuItem(value: cab.id, child: Text(cab.name))),
              ],
              onChanged: (v) => setState(() {
                _selectedCabinetId = v;
                _selectedBoxId = null;
              }),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedBoxId,
              decoration: deco('Box / Shelf'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('No box selected')),
                ...boxes.map((box) =>
                    DropdownMenuItem(value: box.id, child: Text(box.name))),
              ],
              onChanged: _selectedCabinetId == null
                  ? null // disabled until cabinet is chosen
                  : (v) => setState(() => _selectedBoxId = v),
            ),

            // ── Quantity & Unit ─────────────────────────
            _sectionTitle('Quantity & Stock'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: deco('Quantity *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: deco('Unit'),
                    items: _units
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _lowStockController,
                decoration: deco('Low Stock Alert At'),
                keyboardType: TextInputType.number),

            // ── Status ──────────────────────────────────
            _sectionTitle('Status'),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: deco('Item Status'),
              items: _statuses
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s[0].toUpperCase() + s.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),

            // ── Dates ───────────────────────────────────
            _sectionTitle('Dates'),
            _DatePickerField(
              label: 'Production Date',
              date: _productionDate,
              onTap: _pickProductionDate,
              onClear: () => setState(() => _productionDate = null),
            ),
            const SizedBox(height: 12),
            _DatePickerField(
              label: 'Expiry Date',
              date: _expiryDate,
              onTap: _pickExpiryDate,
              onClear: () => setState(() => _expiryDate = null),
            ),

            // ── Extra ───────────────────────────────────
            _sectionTitle('Extra Info'),
            TextFormField(
                controller: _noteController,
                decoration: deco('Notes', hint: 'Any extra information'),
                maxLines: 3),
            const SizedBox(height: 12),
            TextFormField(
                controller: _tagsController,
                decoration: deco('Tags',
                    hint: 'Comma separated, e.g. fever, adult, prescription')),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: itemProvider.isLoading ? null : _save,
              child: Text(
                _isEditing ? 'Update Item' : 'Add Item',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Date picker field widget ──────────────────────────────
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final text = date != null
        ? '${date!.day.toString().padLeft(2, '0')}/'
            '${date!.month.toString().padLeft(2, '0')}/'
            '${date!.year}'
        : 'Not set';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 18, color: subColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: subColor)),
                  const SizedBox(height: 2),
                  Text(text,
                      style: TextStyle(
                          fontSize: 15,
                          color: date != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey.shade400)),
                ],
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: subColor),
              ),
          ],
        ),
      ),
    );
  }
}