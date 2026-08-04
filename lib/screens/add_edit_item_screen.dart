import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/item_model.dart';
import '../models/cabinet_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cabinet_provider.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import '../services/ai_service.dart';
import '../services/iot_service.dart';
import '../services/location_memory_service.dart';
import '../widgets/voice_text_field.dart';

class AddEditItemScreen extends StatefulWidget {
  final ItemModel? item;
  final String? presetCabinetId; // Auto-select cabinet from BLE
  
  const AddEditItemScreen({
    super.key,
    this.item,
    this.presetCabinetId,
  });

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String? _categoryId;
  String? _cabinetId;
  String? _boxId;
  String _unit = 'pcs';
  String _status = 'inside';

  DateTime? _expiryDate;
  DateTime? _productionDate;

  final List<String> _existingImageUrls = [];
  final List<File> _newImages = [];

  bool _isAiLoading = false;
  bool _isSaving = false;
  bool _isImgLoading = false;

  // ── BLE Related ──
  bool _bleConnected = false;
  bool _autoMatchedDevice = false;
  bool _isLoadingLocation = true;
  String? _connectedDeviceId;
  StreamSubscription<String>? _connectionSub;
  
  // ── Location State ──
  bool _isLocationManuallyChanged = false;

  bool get _isEditing => widget.item != null;

  static const _units = ['pcs', 'box', 'bottle', 'pack', 'kg', 'g', 'L', 'ml'];
  static const _statuses = ['inside', 'taken', 'used', 'damaged'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final i = widget.item!;
      _nameCtrl.text = i.name;
      _descCtrl.text = i.description ?? '';
      _brandCtrl.text = i.brand ?? '';
      _qtyCtrl.text = i.quantity.toString();
      _lowStockCtrl.text = i.lowStockThreshold.toString();
      _noteCtrl.text = i.note ?? '';
      _tagsCtrl.text = i.tags.join(', ');
      _categoryId = i.categoryId;
      _cabinetId = i.cabinetId;
      _boxId = i.boxId;
      _unit = i.unit;
      _status = i.status;
      _expiryDate = i.expiryDate;
      _productionDate = i.productionDate;
      _existingImageUrls.addAll(i.imageUrls);
      _isLoadingLocation = false;
    } else {
      _qtyCtrl.text = '1';
      _lowStockCtrl.text = '5';
      _loadInitialLocation();
    }

    // Listen to BLE connection status
    _bleConnected = IoTService().isConnected;
    _connectedDeviceId = IoTService().connectedDeviceId;
    
    _connectionSub = IoTService().connectionStatus.listen((status) {
      if (!mounted) return;
      final wasConnected = _bleConnected;
      setState(() {
        _bleConnected = status == 'Connected';
        _connectedDeviceId = IoTService().connectedDeviceId;
      });

      // If we just connected, reload location to auto-select cabinet
      // BUT only if user hasn't manually changed the location
      if (!wasConnected && _bleConnected && !_isLocationManuallyChanged) {
        _loadInitialLocation();
      }
    });
  }

  // ── Load Initial Location (BLE-integrated) ─────────────────
  Future<void> _loadInitialLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Load categories
      context.read<CategoryProvider>().loadCategories();

      final cabProvider = context.read<CabinetProvider>();

      // Ensure cabinets are loaded
      if (cabProvider.cabinets.isEmpty) {
        await cabProvider.forceLoadCabinets();
        await cabProvider.forceLoadBoxes();
      }

      if (!mounted) return;

      debugPrint('📊 Cabinets loaded: ${cabProvider.cabinets.length}');
      debugPrint('📊 Boxes loaded: ${cabProvider.boxes.length}');

      // ── STEP 0: Check for preset cabinet from BLE ──────────
      if (widget.presetCabinetId != null) {
        final cabinet = cabProvider.getCabinetById(widget.presetCabinetId!);
        if (cabinet != null) {
          setState(() {
            _cabinetId = cabinet.id;
            _autoMatchedDevice = true;
            _isLocationManuallyChanged = false;
          });
          
          // Auto-select first box in this cabinet
          final boxes = cabProvider.getBoxesForCabinet(cabinet.id!);
          if (boxes.isNotEmpty) {
            setState(() {
              _boxId = boxes.first.id;
            });
          }
          debugPrint('✅ Preset cabinet from BLE: ${cabinet.name}');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      // ── STEP 1: Try BLE device matching ──────────────────
      final connectedDeviceId = IoTService().connectedDeviceId;
      
      if (connectedDeviceId != null && cabProvider.cabinets.isNotEmpty) {
        // Find cabinet linked to this BLE device
        final matchedCabinets = cabProvider.cabinets
            .where((c) => c.bleDeviceId == connectedDeviceId)
            .toList();
        
        if (matchedCabinets.isNotEmpty) {
          final matched = matchedCabinets.first;
          debugPrint('🔵 Matched cabinet by BLE device: ${matched.name} (${matched.id})');
          
          setState(() {
            _cabinetId = matched.id;
            _autoMatchedDevice = true;
            _isLocationManuallyChanged = false;
          });
          
          // Auto-select first box in this cabinet
          final boxes = cabProvider.getBoxesForCabinet(matched.id!);
          if (boxes.isNotEmpty && !_isLocationManuallyChanged) {
            setState(() {
              _boxId = boxes.first.id;
            });
            debugPrint('📦 Auto-selected box: ${boxes.first.name}');
          }
          
          setState(() => _isLoadingLocation = false);
          return;
        } else {
          debugPrint('⚠️ No cabinet linked to BLE device: $connectedDeviceId');
        }
      }

      // ── STEP 2: Try remembered location (last used) ─────
      final rememberedCabinetId = await LocationMemoryService().getLastCabinetId();
      final rememberedBoxId = await LocationMemoryService().getLastBoxId();

      if (rememberedCabinetId != null) {
        final cabinetStillExists = cabProvider.cabinets
            .any((c) => c.id == rememberedCabinetId);
        
        if (cabinetStillExists && !_isLocationManuallyChanged) {
          // Check if box still exists
          String? validBoxId;
          if (rememberedBoxId != null) {
            final boxStillExists = cabProvider.boxes
                .any((b) => b.id == rememberedBoxId && b.cabinetId == rememberedCabinetId);
            if (boxStillExists) {
              validBoxId = rememberedBoxId;
            }
          }
          
          setState(() {
            _cabinetId = rememberedCabinetId;
            _boxId = validBoxId;
            _autoMatchedDevice = false;
            _isLocationManuallyChanged = false;
          });
          debugPrint('✅ Restored remembered location: cabinet=$rememberedCabinetId, box=$validBoxId');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      // ── STEP 3: Fallback to first cabinet if available ──
      if (cabProvider.cabinets.isNotEmpty && !_isLocationManuallyChanged) {
        final firstCabinet = cabProvider.cabinets.first;
        setState(() {
          _cabinetId = firstCabinet.id;
          _autoMatchedDevice = false;
          _isLocationManuallyChanged = false;
        });
        
        // Auto-select first box
        final boxes = cabProvider.getBoxesForCabinet(firstCabinet.id!);
        if (boxes.isNotEmpty) {
          setState(() {
            _boxId = boxes.first.id;
          });
        }
        debugPrint('📍 Fallback to first cabinet: ${firstCabinet.name}');
      } else {
        debugPrint('ℹ️ No cabinets available');
      }
      
    } catch (e) {
      debugPrint('❌ Error loading location: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    _lowStockCtrl.dispose();
    _noteCtrl.dispose();
    _tagsCtrl.dispose();
    _connectionSub?.cancel();
    super.dispose();
  }

  // ── Photo picker (supports multiple photos) ───────────
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                'You can add multiple photos. AI can scan a photo to '
                'auto-fill item details.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _srcBtn(Icons.camera_alt, 'Camera',
                      const Color(0xFF4ECDC4),
                      () => Navigator.pop(context, ImageSource.camera))),
                  const SizedBox(width: 12),
                  Expanded(child: _srcBtn(Icons.photo_library, 'Gallery',
                      const Color(0xFF45B7D1),
                      () => Navigator.pop(context, ImageSource.gallery))),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    if (source == ImageSource.gallery) {
      final picked = await ImagePicker()
          .pickMultiImage(imageQuality: 85, maxWidth: 1080);
      if (picked.isEmpty) return;
      setState(() {
        _newImages.addAll(picked.map((x) => File(x.path)));
      });
      _offerAiScan(_newImages.last);
    } else {
      final picked = await ImagePicker().pickImage(
          source: source, imageQuality: 85, maxWidth: 1080);
      if (picked == null) return;
      setState(() => _newImages.add(File(picked.path)));
      _offerAiScan(_newImages.last);
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Widget _srcBtn(IconData icon, String label, Color color,
      VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      );

  void _offerAiScan(File image) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Color(0xFF4ECDC4), size: 28),
            ),
            const SizedBox(height: 14),
            const Text('AI Auto-Fill?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'AI can scan this photo and fill in the item name, '
              'brand, expiry date, category and more automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _autoFillFromImage(image);
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Auto-Fill'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4)),
          ),
        ],
      ),
    );
  }

  Future<void> _autoFillFromImage(File image) async {
    setState(() => _isImgLoading = true);
    try {
      final fill = await AIService().autoFillFromImage(image);
      if (!mounted) return;
      if (fill.isEmpty) {
        _showSnack('AI could not read the image. Fill in manually.');
        return;
      }
      _showAutoFillSheet(fill);
    } catch (e) {
      _showSnack('AI scan failed: $e');
    } finally {
      if (mounted) setState(() => _isImgLoading = false);
    }
  }

  Future<void> _autoFillFromName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _showSnack('Enter an item name first'); return; }
    setState(() => _isAiLoading = true);
    try {
      final fill = await AIService().autoFillFromName(name);
      if (!mounted) return;
      if (fill.isEmpty) {
        _showSnack('AI could not suggest details for "$name".');
        return;
      }
      _showAutoFillSheet(fill);
    } catch (e) {
      _showSnack('AI auto-fill failed: $e');
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  void _showAutoFillSheet(ItemAutoFill fill) {
    final catProvider = context.read<CategoryProvider>();
    final matchedCat = catProvider.getCategoryByName(fill.category);

    final sel = <String, bool>{
      'name': fill.name.isNotEmpty,
      'brand': fill.brand.isNotEmpty,
      'description': fill.description.isNotEmpty,
      'category': matchedCat != null,
      'quantity': fill.quantity > 0,
      'unit': true,
      'expiry': fill.expiryDate != null,
      'production': fill.productionDate != null,
      'note': fill.note.isNotEmpty,
      'tags': fill.tags.isNotEmpty,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        final textColor = Theme.of(ctx).colorScheme.onSurface;
        final subColor = textColor.withValues(alpha: 0.55);

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2)),
                  ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Color(0xFF4ECDC4), size: 18),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Suggestions',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  Text('Select fields to apply',
                      style: TextStyle(fontSize: 11, color: subColor)),
                ]),
              ]),
              const SizedBox(height: 12),
              const Divider(),

              if (fill.name.isNotEmpty)
                _suggestRow(ctx, sel, setLocal, 'name', 'Name',
                    fill.name, Icons.label_outline),
              if (fill.brand.isNotEmpty)
                _suggestRow(ctx, sel, setLocal, 'brand', 'Brand',
                    fill.brand, Icons.business_outlined),
              if (fill.description.isNotEmpty)
                _suggestRow(ctx, sel, setLocal, 'description',
                    'Description', fill.description,
                    Icons.description_outlined),
              if (matchedCat != null)
                _suggestRow(ctx, sel, setLocal, 'category', 'Category',
                    '${matchedCat.icon} ${matchedCat.name}',
                    Icons.category_outlined),
              _suggestRow(ctx, sel, setLocal, 'quantity', 'Quantity',
                  '${fill.quantity} ${fill.unit}',
                  Icons.numbers_outlined),
              if (fill.expiryDate != null)
                _suggestRow(ctx, sel, setLocal, 'expiry', 'Expiry Date',
                    '${fill.expiryDate!.day.toString().padLeft(2,'0')}/'
                    '${fill.expiryDate!.month.toString().padLeft(2,'0')}/'
                    '${fill.expiryDate!.year}',
                    Icons.calendar_today_outlined,
                    highlight: true),
              if (fill.productionDate != null)
                _suggestRow(ctx, sel, setLocal, 'production',
                    'Production Date',
                    '${fill.productionDate!.day.toString().padLeft(2,'0')}/'
                    '${fill.productionDate!.month.toString().padLeft(2,'0')}/'
                    '${fill.productionDate!.year}',
                    Icons.calendar_month_outlined),
              if (fill.note.isNotEmpty)
                _suggestRow(ctx, sel, setLocal, 'note', 'Note',
                    fill.note, Icons.note_outlined),
              if (fill.tags.isNotEmpty)
                _suggestRow(ctx, sel, setLocal, 'tags', 'Tags',
                    fill.tags.join(', '), Icons.local_offer_outlined),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _applyAutoFill(fill, sel, matchedCat?.id);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Apply Selected'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4)),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    );
  }

  Widget _suggestRow(BuildContext ctx, Map<String, bool> sel,
      StateSetter setLocal, String key, String label,
      String value, IconData icon, {bool highlight = false}) {
    final subColor = Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55);
    return InkWell(
      onTap: () => setLocal(() => sel[key] = !(sel[key] ?? false)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Checkbox(
            value: sel[key] ?? false,
            onChanged: (v) => setLocal(() => sel[key] = v!),
            activeColor: const Color(0xFF4ECDC4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
          ),
          Icon(icon, size: 17,
              color: highlight ? Colors.orange : subColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: subColor)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: highlight
                            ? Colors.orange
                            : Theme.of(ctx).colorScheme.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
          ),
        ]),
      ),
    );
  }

  void _applyAutoFill(ItemAutoFill fill, Map<String, bool> sel,
      String? catId) {
    setState(() {
      if (sel['name'] == true && fill.name.isNotEmpty)
        _nameCtrl.text = fill.name;
      if (sel['brand'] == true && fill.brand.isNotEmpty)
        _brandCtrl.text = fill.brand;
      if (sel['description'] == true && fill.description.isNotEmpty)
        _descCtrl.text = fill.description;
      if (sel['category'] == true && catId != null)
        _categoryId = catId;
      if (sel['quantity'] == true) {
        _qtyCtrl.text = fill.quantity.toString();
        _unit = fill.unit;
      }
      if (sel['expiry'] == true && fill.expiryDate != null)
        _expiryDate = fill.expiryDate;
      if (sel['production'] == true && fill.productionDate != null)
        _productionDate = fill.productionDate;
      if (sel['note'] == true && fill.note.isNotEmpty)
        _noteCtrl.text = fill.note;
      if (sel['tags'] == true && fill.tags.isNotEmpty)
        _tagsCtrl.text = fill.tags.join(', ');
    });
    _showSnack('✅ AI fields applied! Review and save.');
  }

  // ── Upload Images ──
  Future<List<String>> _uploadAllImages(String userId) async {
    final urls = <String>[..._existingImageUrls];
    
    for (final file in _newImages) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'item_photos/$userId/${timestamp}_${urls.length}.jpg';
        
        final ref = FirebaseStorage.instance.ref().child(fileName);
        
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );
        
        await ref.putFile(file, metadata);
        final url = await ref.getDownloadURL();
        urls.add(url);
        
        debugPrint('✅ Uploaded image: $fileName');
      } catch (e) {
        debugPrint('❌ Failed to upload image: $e');
        // Continue with other images
      }
    }
    
    return urls;
  }

  // ── SAVE METHOD (FIXED - ensures item appears immediately) ──
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      _showSnack('Please select a category');
      return;
    }

    if (_expiryDate != null) {
      final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day);
      if (_expiryDate!.isBefore(today)) {
        _showExpiredDialog();
        return;
      }
    }

    setState(() => _isSaving = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final itemProvider = context.read<ItemProvider>();
      final userId = authProvider.currentUser?.id ?? '';
      
      if (userId.isEmpty) {
        _showSnack('User not authenticated');
        setState(() => _isSaving = false);
        return;
      }
      
      final now = DateTime.now();

      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Build the base item
      final baseItem = ItemModel(
        id: widget.item?.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _categoryId!,
        cabinetId: _cabinetId,
        boxId: _boxId,
        brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        initialQuantity: _isEditing 
            ? widget.item!.initialQuantity 
            : (int.tryParse(_qtyCtrl.text) ?? 1),
        unit: _unit,
        lowStockThreshold: int.tryParse(_lowStockCtrl.text) ?? 5,
        withdrawalHistory: widget.item?.withdrawalHistory ?? [],
        expiryDate: _expiryDate,
        productionDate: _productionDate,
        status: _status,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        tags: tags,
        imageUrls: List<String>.from(_existingImageUrls),
        isFavorite: widget.item?.isFavorite ?? false,
        takenCount: widget.item?.takenCount ?? 0,
        createdAt: widget.item?.createdAt ?? now,
        updatedAt: now,
        userId: userId,
      );

      if (widget.item == null) {
        // ── ADD NEW ITEM ──
        
        // Upload images first (if any)
        List<String> imageUrls = List.from(_existingImageUrls);
        
        if (_newImages.isNotEmpty) {
          try {
            final uploadedUrls = await _uploadAllImages(userId);
            imageUrls = uploadedUrls;
            debugPrint('✅ Uploaded ${uploadedUrls.length} images');
          } catch (e) {
            debugPrint('⚠️ Photo upload error: $e');
            _showSnack('⚠️ Some photos failed to upload');
          }
        }
        
        // Create the final item with images
        final newItem = baseItem.copyWith(imageUrls: imageUrls);
        
        // ✅ ADD OPTIMISTIC ITEM FIRST (immediate UI feedback)
        final tempItem = itemProvider.addItemLocally(newItem);
        debugPrint('📦 Added optimistic item: ${tempItem.id}');
        
        // Save to Firestore
        final docId = await itemProvider.addItem(newItem);
        
        if (docId == null) {
          // Failed to save - remove the optimistic item
          itemProvider.removeItemLocally(tempItem.id!);
          _showSnack('Error saving item');
          setState(() => _isSaving = false);
          return;
        }
        
        // ✅ Replace local placeholder with real item
        final realItem = newItem.copyWith(id: docId);
        itemProvider.replaceLocalItem(tempItem.id!, realItem);
        debugPrint('✅ Replaced local item with real ID: $docId');
        
        // Remember location for next time
        await LocationMemoryService().saveLocation(
          cabinetId: _cabinetId,
          boxId: _boxId,
        );
        
        if (mounted) {
          // ✅ Force reload to ensure list is up to date
          itemProvider.reloadItems();
          Navigator.pop(context, true);
          _showSnack('✅ Item added successfully');
        }
      } else {
        // ── EDIT EXISTING ITEM ──
        
        // Upload new images if any
        List<String> imageUrls = List.from(_existingImageUrls);
        
        if (_newImages.isNotEmpty) {
          try {
            final uploadedUrls = await _uploadAllImages(userId);
            imageUrls = uploadedUrls;
            debugPrint('✅ Uploaded ${uploadedUrls.length} images');
          } catch (e) {
            debugPrint('⚠️ Photo upload error: $e');
            _showSnack('⚠️ Some photos failed to upload');
          }
        }
        
        final item = baseItem.copyWith(imageUrls: imageUrls);
        
        final ok = await itemProvider.updateItem(item);
        
        if (ok && mounted) {
          await LocationMemoryService().saveLocation(
            cabinetId: _cabinetId,
            boxId: _boxId,
          );
          itemProvider.reloadItems();
          Navigator.pop(context, true);
          _showSnack('✅ Item updated successfully');
        } else if (mounted) {
          _showSnack('Error: ${itemProvider.error ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      debugPrint('❌ Save error: $e');
      if (mounted) {
        _showSnack('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          SizedBox(width: 8),
          Text('Expired Item'),
        ]),
        content: const Text(
          'The expiry date you set is in the past.\n\n'
          'Expired items cannot be added to the cabinet. '
          'Please update the expiry date or clear it.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _pickProduction() async {
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

  Widget _photoThumb({required Widget child, required VoidCallback onRemove}) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearRememberedLocation() async {
    await LocationMemoryService().clear();
    setState(() {
      _cabinetId = null;
      _boxId = null;
      _autoMatchedDevice = false;
      _isLocationManuallyChanged = false;
    });
    _showSnack('Remembered location cleared');
    _loadInitialLocation();
  }

  @override
  Widget build(BuildContext context) {
    final catProvider = context.watch<CategoryProvider>();
    final cabProvider = context.watch<CabinetProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);

    // Get boxes for the selected cabinet
    final boxes = _cabinetId != null
        ? cabProvider.getBoxesForCabinet(_cabinetId!)
        : [];

    InputDecoration deco(String label, {String? hint}) =>
        InputDecoration(
          labelText: label, hintText: hint,
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

    Widget section(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Text(t,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4ECDC4))))
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save',
                      style: TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontWeight: FontWeight.w700,
                          fontSize: 16))),
        ],
      ),
      body: _isLoadingLocation
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                  SizedBox(height: 16),
                  Text('Loading your cabinets...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                children: [
                  // ── PHOTOS (multiple) ──────────────────────
                  section('Photos'),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._existingImageUrls.asMap().entries.map((e) =>
                            _photoThumb(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  e.value,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 100, height: 100,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              onRemove: () => _removeExistingImage(e.key),
                            )),
                        ..._newImages.asMap().entries.map((e) =>
                            _photoThumb(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  e.value,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              onRemove: () => _removeNewImage(e.key),
                            )),
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2D2D2D)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 26,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade400),
                                const SizedBox(height: 4),
                                Text('Add',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isImgLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF4ECDC4))),
                          SizedBox(width: 8),
                          Text('AI scanning…',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF4ECDC4))),
                        ],
                      ),
                    )
                  else if (_existingImageUrls.isEmpty && _newImages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '✨ AI can auto-fill details from a photo',
                        style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF4ECDC4).withValues(alpha: 0.85)),
                      ),
                    ),

                  // ── BASIC INFO ──────────────────────────────
                  section('Basic Info'),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: VoiceTextField(
                          controller: _nameCtrl,
                          label: 'Item Name *',
                          hint: 'e.g. Paracetamol 500mg',
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Name is required' : null,
                          onVoiceResult: (text) {
                            setState(() {});
                            if (text.isNotEmpty) _autoFillFromName();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'AI Auto-fill from name',
                        child: InkWell(
                          onTap: _isAiLoading ? null : _autoFillFromName,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 50, height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECDC4).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF4ECDC4)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: _isAiLoading
                                ? const Center(
                                    child: SizedBox(
                                        width: 18, height: 18,
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
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.mic, size: 12, color: Color(0xFF4ECDC4)),
                        const SizedBox(width: 4),
                        Text(
                          '🎤 Voice input · ✨ AI auto-fill from name',
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF4ECDC4).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  VoiceTextField(
                    controller: _descCtrl,
                    label: 'Description',
                    hint: 'Optional',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  VoiceTextField(
                    controller: _brandCtrl,
                    label: 'Brand',
                    hint: 'Optional',
                  ),

                  // ── CATEGORY ────────────────────────────────
                  section('Category *'),
                  DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: deco('Category'),
                    items: catProvider.categories.map((cat) =>
                        DropdownMenuItem(
                          value: cat.id,
                          child: Row(children: [
                            Text(cat.icon,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(cat.name),
                          ]),
                        )).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    hint: const Text('Select category'),
                    validator: (v) =>
                        v == null ? 'Please select a category' : null,
                  ),

                  // ── LOCATION (OPTIONAL) ─────────────────────
                  section('Location (Optional)'),

                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: (_bleConnected ? Colors.green : const Color(0xFF4ECDC4))
                          .withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: (_bleConnected ? Colors.green : const Color(0xFF4ECDC4))
                              .withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Icon(
                        _bleConnected ? Icons.bluetooth_connected : Icons.info_outline,
                        color: _bleConnected ? Colors.green : const Color(0xFF4ECDC4),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _autoMatchedDevice
                              ? '📍 Location auto-matched from connected smart cabinet'
                              : _bleConnected
                                  ? '🔵 Smart cabinet connected. Location auto-matched automatically.'
                                  : '📍 Location will be remembered for next time. Cabinet and box are optional.',
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ),
                      if (_cabinetId != null)
                        GestureDetector(
                          onTap: _clearRememberedLocation,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _bleConnected
                                    ? Colors.green
                                    : const Color(0xFF4ECDC4),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),

                  // Cabinet Dropdown
                  DropdownButtonFormField<String>(
                    value: _cabinetId,
                    decoration: deco('Cabinet'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No cabinet')),
                      ...cabProvider.cabinets.map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setState(() {
                      _cabinetId = v;
                      _boxId = null;
                      _autoMatchedDevice = false;
                      _isLocationManuallyChanged = true;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Box Dropdown - shows boxes for selected cabinet
                  DropdownButtonFormField<String>(
                    value: _boxId,
                    decoration: deco('Box / Shelf'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No box')),
                      ...boxes.map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: _cabinetId == null
                        ? null
                        : (v) => setState(() {
                            _boxId = v;
                            _isLocationManuallyChanged = true;
                          }),
                  ),

                  // ── QUANTITY ────────────────────────────────
                  section('Quantity & Stock'),
                  Row(children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qtyCtrl,
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
                        items: _units.map((u) =>
                            DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setState(() => _unit = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _lowStockCtrl,
                      decoration: deco('Low Stock Alert At'),
                      keyboardType: TextInputType.number),

                  // ── STATUS ──────────────────────────────────
                  section('Status'),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: deco('Item Status'),
                    items: _statuses.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                            s[0].toUpperCase() + s.substring(1)))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),

                  // ── DATES ───────────────────────────────────
                  section('Dates'),
                  _DateRow(
                    label: 'Production Date',
                    date: _productionDate,
                    onTap: _pickProduction,
                    onClear: () => setState(() => _productionDate = null),
                    isDark: isDark,
                    subColor: subColor,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 12),
                  _DateRow(
                    label: 'Expiry Date',
                    date: _expiryDate,
                    onTap: _pickExpiry,
                    onClear: () => setState(() => _expiryDate = null),
                    isDark: isDark,
                    subColor: subColor,
                    textColor: textColor,
                  ),

                  // ── EXTRA ───────────────────────────────────
                  section('Extra Info'),

                  VoiceTextField(
                    controller: _noteCtrl,
                    label: 'Notes',
                    hint: 'Any extra information',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  VoiceTextField(
                    controller: _tagsCtrl,
                    label: 'Tags',
                    hint: 'Comma separated, e.g. fever, adult',
                  ),

                  const SizedBox(height: 36),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    child: Text(
                      _isEditing ? 'Update Item' : 'Add Item',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool isDark;
  final Color subColor, textColor;

  const _DateRow({
    required this.label, required this.date,
    required this.onTap, required this.onClear,
    required this.isDark, required this.subColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = date != null
        ? '${date!.day.toString().padLeft(2,'0')}/'
          '${date!.month.toString().padLeft(2,'0')}/'
          '${date!.year}'
        : 'Not set';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? Colors.grey.shade700
                  : Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 17, color: subColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: subColor)),
                const SizedBox(height: 2),
                Text(text,
                    style: TextStyle(
                        fontSize: 14,
                        color: date != null
                            ? textColor
                            : Colors.grey.shade400)),
              ],
            ),
          ),
          if (date != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 17, color: subColor),
            ),
        ]),
      ),
    );
  }
}