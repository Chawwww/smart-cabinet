import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import 'add_edit_item_screen.dart';
import 'medicine_info_screen.dart'; // ✅ ADDED for Medicine Info

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen>
    with SingleTickerProviderStateMixin {
  late ItemModel _item;
  late TabController _tabs;
  final _photoPageController = PageController();
  int _photoIndex = 0;
  bool _isSaving     = false;
  bool _isAiCounting = false;

  final _fmt     = DateFormat('dd MMM yyyy');
  final _fmtFull = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _tabs = TabController(length: 3, vsync: this);
    AIService().initialize();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // SUPERVISOR REQ 2: Withdrawal with recording
  // ════════════════════════════════════════════
  Future<void> _showWithdrawDialog() async {
    // SUPERVISOR REQ 3: Block expired items from being taken
    if (_item.isExpired) {
      _showBlockedDialog(
        '🚫 Cannot Take Out — Item Expired',
        '${_item.name} expired on ${_fmt.format(_item.expiryDate!)}.\n\n'
        'Expired items must not be used. '
        'Please remove or discard this item.',
      );
      return;
    }
    if (_item.isOutOfStock) {
      _showSnack('No stock remaining in cabinet.');
      return;
    }

    int qty = 1;
    final noteCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        final textColor = Theme.of(ctx).colorScheme.onSurface;
        final subColor  = textColor.withValues(alpha: 0.55);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text(_item.icon ?? '📦',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Take Out',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    Text(_item.name,
                        style: TextStyle(
                            fontSize: 13,
                            color: subColor)),
                  ],
                ),
              ]),
              const SizedBox(height: 20),

              // Qty picker
              Text('How many?',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(height: 10),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  iconSize: 32,
                  onPressed:
                      qty > 1 ? () => setLocal(() => qty--) : null,
                ),
                Expanded(
                  child: Column(children: [
                    Text('$qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    Text(_item.unit,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: subColor)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF4ECDC4),
                  iconSize: 32,
                  onPressed: qty < _item.quantity
                      ? () => setLocal(() => qty++)
                      : null,
                ),
              ]),
              Text(
                'Available: ${_item.quantity} ${_item.unit}',
                style: TextStyle(fontSize: 12, color: subColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Reason note
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason / Note (optional)',
                  hintText: 'e.g. for headache, cooking dinner',
                  prefixIcon: Icon(Icons.note_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _doWithdraw(qty, noteCtrl.text.trim());
                  },
                  icon: const Icon(Icons.arrow_circle_down),
                  label: Text('Take Out $qty ${_item.unit}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _doWithdraw(int qty, String note) async {
    final authProvider = context.read<AuthProvider>();
    final takenBy = authProvider.currentUser?.name ?? 'Unknown';

    setState(() => _isSaving = true);

    final ok = await context.read<ItemProvider>().recordWithdrawal(
      item: _item,
      qty: qty,
      takenBy: takenBy,
      note: note.isEmpty ? null : note,
    );

    if (ok && mounted) {
      // Refresh local state from provider
      final updated = context.read<ItemProvider>().getItemById(_item.id!);
      if (updated != null) setState(() => _item = updated);

      _showSnack('✅ Took out $qty ${_item.unit}');

      // SUPERVISOR REQ 3: Warn on low stock after withdrawal
      if (_item.isLowStock) {
        _showBanner(
          '⚠️ Low Stock — Only ${_item.quantity} ${_item.unit} left. Consider restocking.',
          Colors.orange,
        );
      }
    }
    setState(() => _isSaving = false);
  }

  // ════════════════════════════════════════════
  // SUPERVISOR REQ 6: AI COUNT FROM PHOTO
  // ════════════════════════════════════════════
  Future<void> _aiCountFromPhoto() async {
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
            children: [
              const Text('AI Count Items',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Take a photo of the cabinet shelf. '
                'AI will count how many "${_item.name}" are visible.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF636E72)),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _photoBtn(Icons.camera_alt, 'Camera',
                    const Color(0xFF4ECDC4),
                    () => Navigator.pop(context, ImageSource.camera))),
                const SizedBox(width: 12),
                Expanded(child: _photoBtn(Icons.photo_library, 'Gallery',
                    const Color(0xFF45B7D1),
                    () => Navigator.pop(context, ImageSource.gallery))),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await ImagePicker().pickImage(
        source: source, imageQuality: 80, maxWidth: 1280);
    if (picked == null) return;

    setState(() => _isAiCounting = true);
    try {
      final result = await AIService()
          .countItemsFromPhoto(File(picked.path), _item.name);
      if (!mounted) return;
      _showAiCountResult(result);
    } catch (e) {
      if (mounted) _showSnack('AI count failed: $e');
    } finally {
      if (mounted) setState(() => _isAiCounting = false);
    }
  }

  void _showAiCountResult(AiCountResult result) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.auto_awesome, color: Color(0xFF4ECDC4)),
          SizedBox(width: 8),
          Text('AI Count Result'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${result.count}',
                style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4ECDC4))),
            Text('${_item.unit} detected',
                style: TextStyle(fontSize: 14, color: subColor)),
            const SizedBox(height: 12),
            // Confidence bar
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.confidence,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: result.confidence > 0.7
                        ? const Color(0xFF00B894)
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(result.confidence * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            if (result.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(result.notes,
                    style: TextStyle(fontSize: 12, color: textColor)),
              ),
            ],
            const SizedBox(height: 10),
            // SUPERVISOR REQ 7: System limitation notice
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '⚠️ System Limitation: AI counting accuracy '
                'depends on image clarity and item visibility. '
                'Stacked or partially hidden items may not be '
                'counted correctly. Always verify physically.',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade800,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyAiCount(result.count);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4)),
            child: const Text('Update Quantity'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyAiCount(int count) async {
    final now = DateTime.now();
    final updated = _item.copyWith(
      quantity:          count,
      aiCountedQuantity: count,
      aiCountedAt:       now,
      status:            count == 0 ? 'taken' : 'inside',
      updatedAt:         now,
    );
    setState(() => _item = updated);
    await context.read<ItemProvider>().updateItem(updated);
    _showSnack('✅ Quantity updated to $count ${_item.unit} (AI counted)');
  }

  Future<void> _returnItem() async {
    setState(() => _isSaving = true);
    final now = DateTime.now();
    final updated = _item.copyWith(
      quantity:  _item.quantity + 1,
      status:    'inside',
      updatedAt: now,
    );
    setState(() => _item = updated);
    await context.read<ItemProvider>().updateItem(updated);
    setState(() => _isSaving = false);
    _showSnack('✅ Returned 1 ${_item.unit}');
  }

  Future<void> _toggleFavourite() async {
    final updated = _item.copyWith(
      isFavorite: !_item.isFavorite,
      updatedAt: DateTime.now(),
    );
    setState(() => _item = updated);
    await context.read<ItemProvider>().updateItem(updated);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content:
            Text('Delete "${_item.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<ItemProvider>().deleteItem(_item.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showBlockedDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(title,
              style: const TextStyle(fontSize: 15))),
        ]),
        content: Text(msg),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showBanner(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 4),
    ));
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  Widget _photoBtn(IconData icon, String label, Color color,
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
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ── Check if item is medicine ──────────────────────────
  bool _isMedicine() {
    // Check category
    if (_item.categoryId.toLowerCase().contains('med')) return true;
    
    // Check tags
    final medicineTags = ['medicine', 'drug', 'tablet', 'capsule', 
        'syrup', '药', '药物', 'pharmacy', 'pill', 'medication'];
    if (_item.tags.any((t) => 
        medicineTags.any((tag) => t.toLowerCase().contains(tag)))) {
      return true;
    }
    
    // Check name
    final medicineNames = ['tablet', 'capsule', 'syrup', 'mg', 'ml', 
        '药', '药物', 'med', 'pill', 'ointment', 'cream'];
    final lowerName = _item.name.toLowerCase();
    if (medicineNames.any((n) => lowerName.contains(n))) return true;
    
    return false;
  }

  // ════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    Color accent;
    try {
      accent = _item.color != null
          ? Color(int.parse(_item.color!.replaceFirst('#', '0xFF')))
          : const Color(0xFF4ECDC4);
    } catch (_) {
      accent = const Color(0xFF4ECDC4);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: textColor),
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              _item.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _item.isFavorite ? Colors.red : subColor,
            ),
            onPressed: _toggleFavourite,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF4ECDC4)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddEditItemScreen(item: _item)),
              );
              if (result == true && mounted) {
                final updated = context
                    .read<ItemProvider>()
                    .getItemById(_item.id!);
                if (updated != null) setState(() => _item = updated);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF4ECDC4)),
            onPressed: () => Share.share(
              '${_item.name}\nQty: ${_item.quantity} ${_item.unit}'
              '${_item.hasExpiry ? "\nExpiry: ${_fmt.format(_item.expiryDate!)}" : ""}'
              '\nShared from Smart Cabinet Finder',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // SUPERVISOR REQ 5: Photo(s) displayed directly, swipeable
          _buildHeroImage(accent, isDark),

          // Expiry warning banner
          if (_item.isExpired)
            _banner('🚫 EXPIRED — ${_fmt.format(_item.expiryDate!)}  '
                'Do not use or take out.', Colors.red),
          if (_item.isExpiringSoon && !_item.isExpired)
            _banner('⚠️ Expiring Soon — ${_item.daysLeftText}  '
                'Consume or restock before '
                '${_fmt.format(_item.expiryDate!)}.',
                Colors.orange),
          if (_item.isLowStock && !_item.isExpired)
            _banner('📉 Low Stock — ${_item.quantity} ${_item.unit} remaining.',
                const Color(0xFFFDCB6E)),

          // Tabs
          TabBar(
            controller: _tabs,
            labelColor: const Color(0xFF4ECDC4),
            unselectedLabelColor: subColor,
            indicatorColor: const Color(0xFF4ECDC4),
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12),
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Quantity'),
              Tab(text: 'History'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildDetails(textColor, subColor, isDark, accent),
                _buildQuantity(textColor, subColor, isDark),
                _buildHistory(textColor, subColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero image / photo carousel ─────────────────────────
  Widget _buildHeroImage(Color accent, bool isDark) {
    final images = _item.imageUrls;

    if (images.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
        child: Center(
            child: Text(_item.icon ?? '📦',
                style: const TextStyle(fontSize: 72))),
      );
    }

    return Stack(
      children: [
        Container(
          height: 180,
          width: double.infinity,
          color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
          child: PageView.builder(
            controller: _photoPageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _photoIndex = i),
            itemBuilder: (_, i) => Image.network(
              images[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(_item.icon ?? '📦',
                      style: const TextStyle(fontSize: 72))),
            ),
          ),
        ),
        if (images.length > 1) ...[
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _photoIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 8 : 6,
                  height: active ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_photoIndex + 1}/${images.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _banner(String msg, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: color.withValues(alpha: 0.15),
        child: Text(msg,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600)),
      );

  // ── DETAILS TAB ─────────────────────────────────────────
  Widget _buildDetails(
      Color textColor, Color subColor, bool isDark, Color accent) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status
        Row(children: [
          _statusChip(_item.status),
          const SizedBox(width: 8),
          if (_item.lastTakenBy != null)
            Expanded(
              child: Text(
                'Last by ${_item.lastTakenBy}'
                '${_item.lastTakenTime != null ? " · ${_fmt.format(_item.lastTakenTime!)}" : ""}',
                style: TextStyle(fontSize: 11, color: subColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ]),
        const SizedBox(height: 14),

        // ── Description shown prominently right up top ──
        if (_item.description != null &&
            _item.description!.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.description_outlined, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text('Description',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                ]),
                const SizedBox(height: 8),
                Text(
                  _item.description!,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: textColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ✅ Medicine Info Button (only for medicine items)
        _buildMedicineInfoButton(),

        _infoCard(textColor, [
          if (_item.brand != null)
            _row('Brand', _item.brand!, textColor, subColor),
          if (_item.note != null)
            _row('Note', _item.note!, textColor, subColor),
          if (_item.tags.isNotEmpty)
            _row('Tags', _item.tags.join(', '), textColor, subColor),
        ]),
        const SizedBox(height: 10),

        _infoCard(textColor, [
          if (_item.hasExpiry)
            _row('Expiry Date', _fmt.format(_item.expiryDate!),
                textColor, subColor,
                color: _item.isExpired
                    ? Colors.red
                    : _item.isExpiringSoon
                        ? Colors.orange
                        : null),
          if (_item.productionDate != null)
            _row('Production Date', _fmt.format(_item.productionDate!),
                textColor, subColor),
          _row('Unit', _item.unit, textColor, subColor),
          _row('Low Stock Alert',
              '${_item.lowStockThreshold} ${_item.unit}',
              textColor, subColor),
        ]),

        if (_item.aiCountedAt != null) ...[
          const SizedBox(height: 10),
          _infoCard(textColor, [
            _row('AI Counted', '${_item.aiCountedQuantity} ${_item.unit}',
                textColor, subColor),
            _row('Count Date', _fmtFull.format(_item.aiCountedAt!),
                textColor, subColor),
          ], header: '🤖 AI Count Record'),
        ],

        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text('Delete Item',
              style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── ✅ Medicine Info Button ─────────────────────────────
  Widget _buildMedicineInfoButton() {
    if (!_isMedicine()) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MedicineInfoScreen(),
          ),
        ),
        icon: const Text('💊', style: TextStyle(fontSize: 18)),
        label: const Text(
          '药物查询 / Medicine Info',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ── QUANTITY TAB ────────────────────────────────────────
  // SUPERVISOR REQ 1: Clear quantity tracking and display
  Widget _buildQuantity(
      Color textColor, Color subColor, bool isDark) {
    final pct = _item.usagePercent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Three-number display
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _qtyBox('In Cabinet', '${_item.quantity}',
                      const Color(0xFF4ECDC4), _item.unit, textColor),
                  Container(width: 1, height: 50,
                      color: Colors.grey.shade300),
                  _qtyBox('Initial', '${_item.initialQuantity}',
                      const Color(0xFF45B7D1), _item.unit, textColor),
                  Container(width: 1, height: 50,
                      color: Colors.grey.shade300),
                  _qtyBox('Total Used', '${_item.totalWithdrawn}',
                      Colors.orange, _item.unit, textColor),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Usage',
                        style: TextStyle(
                            fontSize: 12, color: subColor)),
                    Text(
                        '${(pct * 100).toInt()}% consumed',
                        style: TextStyle(
                            fontSize: 12, color: subColor)),
                  ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: pct > 0.8
                      ? Colors.red
                      : pct > 0.5
                          ? Colors.orange
                          : const Color(0xFF4ECDC4),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Action buttons
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _showWithdrawDialog,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_circle_down),
              label: const Text('Take Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _returnItem,
              icon: const Icon(Icons.arrow_circle_up),
              label: const Text('Return 1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF2D2D2D)
                    : Colors.grey.shade200,
                foregroundColor: textColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // AI count button
        OutlinedButton.icon(
          onPressed: _isAiCounting ? null : _aiCountFromPhoto,
          icon: _isAiCounting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4ECDC4)))
              : const Icon(Icons.auto_awesome,
                  color: Color(0xFF4ECDC4), size: 18),
          label: const Text('AI Count from Photo',
              style: TextStyle(color: Color(0xFF4ECDC4))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF4ECDC4)),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 4),
        // SUPERVISOR REQ 7: Limitation notice
        Text(
          '⚠️ Limitation: AI counting accuracy depends on photo '
          'quality and item visibility. Physical verification is '
          'always recommended.',
          style: TextStyle(
              fontSize: 10,
              color: subColor,
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── HISTORY TAB ─────────────────────────────────────────
  Widget _buildHistory(Color textColor, Color subColor) {
    final history = List.from(_item.withdrawalHistory.reversed);

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60,
                color: subColor.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text('No withdrawal history yet',
                style: TextStyle(fontSize: 15, color: subColor)),
            const SizedBox(height: 6),
            Text('Use "Take Out" to record withdrawals',
                style: TextStyle(fontSize: 12, color: subColor)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final rec  = history[i] as Map<String, dynamic>;
        final qty  = rec['qty'] as int? ?? 0;
        final by   = rec['by']  as String? ?? 'Unknown';
        final note = rec['note'] as String?;
        DateTime? at;
        try { at = DateTime.parse(rec['at'] as String); } catch (_) {}

        return Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('−$qty',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$qty ${_item.unit} taken by $by',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor),
                    ),
                    if (note != null && note.isNotEmpty)
                      Text(note,
                          style: TextStyle(
                              fontSize: 12, color: textColor
                                  .withValues(alpha: 0.6))),
                    if (at != null)
                      Text(_fmtFull.format(at),
                          style: TextStyle(
                              fontSize: 11, color: textColor
                                  .withValues(alpha: 0.45))),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── UI Helpers ──────────────────────────────────────────
  Widget _statusChip(String status) {
    Color c;
    switch (status) {
      case 'inside':  c = const Color(0xFF00B894); break;
      case 'taken':   c = const Color(0xFFFDCB6E); break;
      case 'used':    c = const Color(0xFF6C5CE7); break;
      case 'damaged': c = Colors.red; break;
      default:        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: c, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11)),
    );
  }

  Widget _infoCard(Color textColor, List<Widget> rows,
      {String? header}) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[
              Text(header,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF4ECDC4))),
              const Divider(height: 14),
            ],
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      Color textColor, Color subColor, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: subColor)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color ?? textColor)),
            ),
          ],
        ),
      );

  Widget _qtyBox(String label, String value, Color color,
      String unit, Color textColor) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(unit,
            style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.5))),
      ]);
}