import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';
import 'add_edit_item_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late ItemModel _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'inside':  return const Color(0xFF00B894);
      case 'taken':   return const Color(0xFFFDCB6E);
      case 'used':    return const Color(0xFF6C5CE7);
      case 'damaged': return Colors.red;
      default:        return Colors.grey;
    }
  }

  Color _expiryColor(String status) {
    switch (status) {
      case 'expired':       return Colors.red;
      case 'expiring_soon': return Colors.orange;
      default:              return Colors.grey;
    }
  }

  Future<void> _toggleFavorite() async {
    final updated = _item.copyWith(isFavorite: !_item.isFavorite);
    await context.read<ItemProvider>().updateItem(updated);
    if (mounted) setState(() => _item = updated);
  }

  Future<void> _updateQuantity(int delta) async {
    final newQty = (_item.quantity + delta).clamp(0, 99999);
    final updated = _item.copyWith(
      quantity: newQty,
      status: newQty == 0 ? 'taken' : 'inside',
    );
    await context.read<ItemProvider>().updateItem(updated);
    if (mounted) {
      setState(() => _item = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(delta > 0
            ? 'Returned 1 ${_item.unit}'
            : 'Took out 1 ${_item.unit}'),
        backgroundColor: const Color(0xFF4ECDC4),
      ));
    }
  }

  void _shareItem() {
    final fmt = DateFormat('MMM dd, yyyy');
    Share.share('''
${_item.name}
${_item.description ?? ''}
Quantity: ${_item.quantity} ${_item.unit}
${_item.hasExpiry ? 'Expiry: ${fmt.format(_item.expiryDate!)}' : ''}
${_item.brand != null ? 'Brand: ${_item.brand}' : ''}
Shared from Smart Cabinet Finder
''');
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM dd, yyyy');
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    Color iconBg;
    try {
      iconBg = _item.color != null
          ? Color(int.parse(_item.color!.replaceFirst('#', '0xFF')))
              .withValues(alpha: isDark ? 0.18 : 0.1)
          : const Color(0xFF4ECDC4).withValues(alpha: isDark ? 0.18 : 0.1);
    } catch (_) {
      iconBg = const Color(0xFF4ECDC4).withValues(alpha: 0.1);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name,
            style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        actions: [
          IconButton(
            icon: Icon(
              _item.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _item.isFavorite ? Colors.red : subColor,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF4ECDC4)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddEditItemScreen(item: _item)),
              );
              if (result == true && mounted) {
                // Reload item from provider
                final updated = context
                    .read<ItemProvider>()
                    .items
                    .firstWhere((i) => i.id == _item.id, orElse: () => _item);
                setState(() => _item = updated);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF4ECDC4)),
            onPressed: _shareItem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(_item.icon ?? '📦',
                      style: const TextStyle(fontSize: 60)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(_item.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _item.status.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Info card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', _item.name, textColor, subColor),
                    if (_item.brand != null) ...[
                      const Divider(height: 20),
                      _infoRow('Brand', _item.brand!, textColor, subColor),
                    ],
                    if (_item.description != null) ...[
                      const Divider(height: 20),
                      _infoRow('Description', _item.description!, textColor, subColor),
                    ],
                    if (_item.note != null) ...[
                      const Divider(height: 20),
                      _infoRow('Note', _item.note!, textColor, subColor),
                    ],
                    if (_item.tags.isNotEmpty) ...[
                      const Divider(height: 20),
                      Text('Tags', style: TextStyle(color: subColor, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: _item.tags
                            .map((t) => Chip(
                                  label: Text(t,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: const Color(0xFF4ECDC4)
                                      .withValues(alpha: 0.15),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quantity card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_item.quantity} ${_item.unit}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                        if (_item.isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Low Stock',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Low stock alert at ${_item.lowStockThreshold} ${_item.unit}',
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Expiry card
            if (_item.hasExpiry)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expiry',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fmt.format(_item.expiryDate!),
                              style: TextStyle(fontSize: 16, color: textColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _expiryColor(_item.expiryStatus),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_item.daysLeftText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (_item.productionDate != null) ...[
                        const Divider(height: 20),
                        Text('Production Date',
                            style:
                                TextStyle(fontSize: 12, color: subColor)),
                        const SizedBox(height: 4),
                        Text(fmt.format(_item.productionDate!),
                            style: TextStyle(fontSize: 14, color: textColor)),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateQuantity(-1),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4)),
                    icon: const Icon(Icons.remove),
                    label: const Text('Take Out'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateQuantity(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF2D2D2D)
                          : Colors.grey.shade200,
                      foregroundColor: textColor,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Return'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Item'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textColor, Color subColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: subColor)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${_item.name}"? This cannot be undone.'),
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
}