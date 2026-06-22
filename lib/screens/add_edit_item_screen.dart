import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  // Controllers
  final _nameController        = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController       = TextEditingController();
  final _quantityController    = TextEditingController();
  final _lowStockController    = TextEditingController();
  final _noteController        = TextEditingController();
  final _tagsController        = TextEditingController();

  // Selections
  String? _selectedCategoryId;
  String? _selectedCabinetId;
  String? _selectedBoxId;
  String  _unit   = 'pcs';
  String  _status = 'inside';

  // Dates
  DateTime? _expiryDate;
  DateTime? _productionDate;

  // Photo
  File?   _imageFile;
  String? _existingImageUrl;

  // AI states
  bool _isAiLoading    = false; // name-based autofill
  bool _isImageLoading = false; // image-based autofill
  bool _isSaving       = false;

  // ── Show the AI suggestions panel?
  bool _showSuggestions = false;
  ItemAutoFill? _lastSuggestion;

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
      _selectedCategoryId  = item.categoryId;
      _selectedCabinetId   = item.cabinetId;
      _selectedBoxId       = item.boxId;
      _unit                = item.unit;
      _status              = item.status;
      _expiryDate          = item.expiryDate;
      _productionDate      = item.productionDate;
      _existingImageUrl    = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;
    } else {
      _quantityController.text = '1';
      _lowStockController.text = '5';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
      context.read<CabinetProvider>()
        ..loadCabinets()
        ..loadBoxes();
      // Init AI
      AIService().initialize();
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

  // ════════════════════════════════════════════════════
  // PHOTO PICKER
  // ════════════════════════════════════════════════════

  Future<void> _showPhotoPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Photo',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text('Take a photo or choose from gallery.\nAI can auto-fill item details from the photo.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _photoOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      color: const Color(0xFF4ECDC4),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _photoOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      color: const Color(0xFF45B7D1),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                  if (_imageFile != null || _existingImageUrl != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _photoOption(
                        icon: Icons.delete_outline,
                        label: 'Remove',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _imageFile = null;
                            _existingImageUrl = null;
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (picked == null) return;

      setState(() => _imageFile = File(picked.path));

      // Immediately offer AI autofill from the image
      _showImageAutoFillDialog();
    } catch (e) {
      _showSnack('Could not pick image: $e');
    }
  }

  // ════════════════════════════════════════════════════
  // AI AUTO-FILL FROM IMAGE
  // ════════════════════════════════════════════════════

  void _showImageAutoFillDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Color(0xFF4ECDC4), size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Use AI Auto-Fill?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'AI can scan the photo and automatically fill in item name, brand, expiry date, category and more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _autoFillFromImage();
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Auto-Fill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _autoFillFromImage() async {
    if (_imageFile == null) return;
    setState(() => _isImageLoading = true);

    try {
      final suggestion = await AIService().autoFillFromImage(_imageFile!);
      if (!mounted) return;

      if (suggestion.isEmpty) {
        _showSnack('AI could not read the image clearly. Please fill in manually.');
        return;
      }

      setState(() {
        _lastSuggestion  = suggestion;
        _showSuggestions = true;
      });

      _showAutoFillResult(suggestion, fromImage: true);
    } catch (e) {
      _showSnack('AI image scan failed: $e');
    } finally {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  // ════════════════════════════════════════════════════
  // AI AUTO-FILL FROM NAME
  // ════════════════════════════════════════════════════

  Future<void> _autoFillFromName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Type an item name first');
      return;
    }
    setState(() => _isAiLoading = true);

    try {
      final suggestion = await AIService().autoFillFromName(name);
      if (!mounted) return;

      if (suggestion.isEmpty) {
        _showSnack('AI could not suggest details for "$name".');
        return;
      }

      setState(() {
        _lastSuggestion  = suggestion;
        _showSuggestions = true;
      });

      _showAutoFillResult(suggestion, fromImage: false);
    } catch (e) {
      _showSnack('AI auto-fill failed: $e');
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  // ════════════════════════════════════════════════════
  // APPLY AUTO-FILL RESULT
  // Shows a bottom sheet with the AI suggestions and lets
  // the user choose which fields to apply.
  // ════════════════════════════════════════════════════

  void _showAutoFillResult(ItemAutoFill fill, {required bool fromImage}) {
    final categoryProvider = context.read<CategoryProvider>();

    // Pre-find the matching category id
    final matchedCat = categoryProvider.getCategoryByName(fill.category);

    // Track which fields user selects to apply
    final selected = {
      'name':        fill.name.isNotEmpty,
      'brand':       fill.brand.isNotEmpty,
      'description': fill.description.isNotEmpty,
      'category':    matchedCat != null,
      'quantity':    fill.quantity > 0,
      'unit':        true,
      'expiry':      fill.expiryDate != null,
      'production':  fill.productionDate != null,
      'note':        fill.note.isNotEmpty,
      'tags':        fill.tags.isNotEmpty,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          final textColor = Theme.of(ctx).colorScheme.onSurface;
          final subColor  = textColor.withValues(alpha: 0.55);

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Color(0xFF4ECDC4), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fromImage ? 'AI Scanned Photo' : 'AI Suggested Details',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor),
                          ),
                          Text('Select which fields to apply',
                              style: TextStyle(fontSize: 12, color: subColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Field checkboxes
                if (fill.name.isNotEmpty)
                  _suggestionRow(ctx, selected, setLocal, 'name',
                      'Name', fill.name, Icons.label_outline),

                if (fill.brand.isNotEmpty)
                  _suggestionRow(ctx, selected, setLocal, 'brand',
                      'Brand', fill.brand, Icons.business_outlined),

                if (fill.description.isNotEmpty)
                  _suggestionRow(ctx, selected, setLocal, 'description',
                      'Description', fill.description, Icons.description_outlined),

                if (matchedCat != null)
                  _suggestionRow(ctx, selected, setLocal, 'category',
                      'Category', '${matchedCat.icon} ${matchedCat.name}',
                      Icons.category_outlined),

                _suggestionRow(ctx, selected, setLocal, 'quantity',
                    'Quantity', '${fill.quantity} ${fill.unit}',
                    Icons.numbers_outlined),

                if (fill.expiryDate != null)
                  _suggestionRow(ctx, selected, setLocal, 'expiry',
                      'Expiry Date',
                      '${fill.expiryDate!.day.toString().padLeft(2, '0')}/'
                          '${fill.expiryDate!.month.toString().padLeft(2, '0')}/'
                          '${fill.expiryDate!.year}',
                      Icons.calendar_today_outlined,
                      highlight: true),

                if (fill.productionDate != null)
                  _suggestionRow(ctx, selected, setLocal, 'production',
                      'Production Date',
                      '${fill.productionDate!.day.toString().padLeft(2, '0')}/'
                          '${fill.productionDate!.month.toString().padLeft(2, '0')}/'
                          '${fill.productionDate!.year}',
                      Icons.calendar_month_outlined),

                if (fill.note.isNotEmpty)
                  _suggestionRow(ctx, selected, setLocal, 'note',
                      'Note', fill.note, Icons.note_outlined),

                if (fill.tags.isNotEmpty)
                  _suggestionRow(ctx, selected, setLocal, 'tags',
                      'Tags', fill.tags.join(', '), Icons.local_offer_outlined),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Apply / Cancel
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyAutoFill(fill, selected, matchedCat?.id);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Apply Selected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _suggestionRow(
    BuildContext ctx,
    Map<String, bool> selected,
    StateSetter setLocal,
    String key,
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    final subColor = Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55);

    return InkWell(
      onTap: () => setLocal(() => selected[key] = !(selected[key] ?? false)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: selected[key] ?? false,
              onChanged: (v) => setLocal(() => selected[key] = v!),
              activeColor: const Color(0xFF4ECDC4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            Icon(icon, size: 18, color: highlight ? Colors.orange : subColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 11, color: subColor)),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: highlight
                          ? Colors.orange
                          : Theme.of(ctx).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyAutoFill(
      ItemAutoFill fill, Map<String, bool> selected, String? categoryId) {
    setState(() {
      if (selected['name'] == true && fill.name.isNotEmpty) {
        _nameController.text = fill.name;
      }
      if (selected['brand'] == true && fill.brand.isNotEmpty) {
        _brandController.text = fill.brand;
      }
      if (selected['description'] == true && fill.description.isNotEmpty) {
        _descriptionController.text = fill.description;
      }
      if (selected['category'] == true && categoryId != null) {
        _selectedCategoryId = categoryId;
      }
      if (selected['quantity'] == true) {
        _quantityController.text = fill.quantity.toString();
        _unit = fill.unit;
      }
      if (selected['expiry'] == true && fill.expiryDate != null) {
        _expiryDate = fill.expiryDate;
      }
      if (selected['production'] == true && fill.productionDate != null) {
        _productionDate = fill.productionDate;
      }
      if (selected['note'] == true && fill.note.isNotEmpty) {
        _noteController.text = fill.note;
      }
      if (selected['tags'] == true && fill.tags.isNotEmpty) {
        _tagsController.text = fill.tags.join(', ');
      }
      _showSuggestions = false;
    });

    _showSnack('✅ AI fields applied! Review and save.');
  }

  // ════════════════════════════════════════════════════
  // UPLOAD PHOTO TO FIREBASE STORAGE
  // ════════════════════════════════════════════════════

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return _existingImageUrl;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('item_photos/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════
  // SAVE
  // ════════════════════════════════════════════════════

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showSnack('Please select a category');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final itemProvider = context.read<ItemProvider>();
      final userId       = authProvider.currentUser?.id ?? '';
      final now          = DateTime.now();

      // Upload image if new one picked
      final imageUrl = await _uploadImage(userId);

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
        cabinetId:        _selectedCabinetId,
        boxId:            _selectedBoxId,
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
        imageUrls:        imageUrl != null ? [imageUrl] : [],
        isFavorite:       widget.item?.isFavorite ?? false,
        takenCount:       widget.item?.takenCount ?? 0,
        createdAt:        widget.item?.createdAt ?? now,
        updatedAt:        now,
        userId:           userId,
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ════════════════════════════════════════════════════
  // DATE PICKERS
  // ════════════════════════════════════════════════════

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final cabinetProvider  = context.watch<CabinetProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);

    final boxes = _selectedCabinetId != null
        ? cabinetProvider.getBoxesForCabinet(_selectedCabinetId!)
        : cabinetProvider.boxes;

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF4ECDC4), width: 1.5)),
        );

    Widget sectionTitle(String title) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: textColor)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add Item'),
        actions: [
          _isSaving
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
                          fontWeight: FontWeight.w700,
                          fontSize: 16))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [

            // ── PHOTO SECTION ──────────────────────────
            sectionTitle('Photo'),
            GestureDetector(
              onTap: _showPhotoPicker,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2D2D2D)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      width: 1.5),
                ),
                child: _imageFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          ),
                          // AI scanning overlay
                          if (_isImageLoading)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                      color: Color(0xFF4ECDC4)),
                                  SizedBox(height: 12),
                                  Text('AI scanning photo…',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          // Edit icon
                          if (!_isImageLoading)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.edit,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                        ],
                      )
                    : _existingImageUrl != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(_existingImageUrl!,
                                    fit: BoxFit.cover),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.edit,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  size: 40,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('Tap to add photo',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade500)),
                              const SizedBox(height: 4),
                              Text('AI can auto-fill details from the photo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: const Color(0xFF4ECDC4)
                                          .withValues(alpha: 0.8))),
                            ],
                          ),
              ),
            ),

            // ── BASIC INFO ─────────────────────────────
            sectionTitle('Basic Info'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: deco('Item Name *',
                        hint: 'e.g. Paracetamol 500mg'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),

                // AI Auto-fill from name button
                Column(
                  children: [
                    Tooltip(
                      message: 'AI: Auto-fill from name',
                      child: InkWell(
                        onTap: _isAiLoading ? null : _autoFillFromName,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 50,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ECDC4)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF4ECDC4)
                                    .withValues(alpha: 0.5)),
                          ),
                          child: _isAiLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF4ECDC4)),
                                  ))
                              : const Icon(Icons.auto_awesome,
                                  color: Color(0xFF4ECDC4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Hint under the name field
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '✨ Tap ✨ to auto-fill fields from the item name using AI',
                style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.8)),
              ),
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

            // ── CATEGORY ───────────────────────────────
            sectionTitle('Category *'),
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
              validator: (v) =>
                  v == null ? 'Please select a category' : null,
            ),

            // ── LOCATION (OPTIONAL) ────────────────────
            sectionTitle('Location (Optional)'),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF4ECDC4), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Skip now and assign a cabinet/box later.',
                      style: TextStyle(fontSize: 12, color: subColor),
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
                    value: null, child: Text('No cabinet')),
                ...cabinetProvider.cabinets.map((c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.name))),
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
                const DropdownMenuItem(value: null, child: Text('No box')),
                ...boxes.map((b) =>
                    DropdownMenuItem(value: b.id, child: Text(b.name))),
              ],
              onChanged: _selectedCabinetId == null
                  ? null
                  : (v) => setState(() => _selectedBoxId = v),
            ),

            // ── QUANTITY ───────────────────────────────
            sectionTitle('Quantity & Stock'),
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

            // ── STATUS ─────────────────────────────────
            sectionTitle('Status'),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: deco('Item Status'),
              items: _statuses
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                          s[0].toUpperCase() + s.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),

            // ── DATES ──────────────────────────────────
            sectionTitle('Dates'),
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

            // ── NOTES & TAGS ───────────────────────────
            sectionTitle('Extra Info'),
            TextFormField(
                controller: _noteController,
                decoration: deco('Notes', hint: 'Any extra information'),
                maxLines: 3),
            const SizedBox(height: 12),
            TextFormField(
                controller: _tagsController,
                decoration: deco('Tags',
                    hint: 'e.g. fever, adult, prescription')),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
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

// ════════════════════════════════════════════════════
// DATE PICKER FIELD WIDGET
// ════════════════════════════════════════════════════

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
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final text     = date != null
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
              color: isDark
                  ? Colors.grey.shade700
                  : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: subColor),
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
                  child: Icon(Icons.close, size: 18, color: subColor)),
          ],
        ),
      ),
    );
  }
}