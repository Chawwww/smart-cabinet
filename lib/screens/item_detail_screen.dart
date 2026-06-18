import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF2FFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2FFFF),
        elevation: 0,
        title: Text(
          item.name,
          style: const TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              item.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: item.isFavorite ? Colors.red : const Color(0xFF636E72),
            ),
            onPressed: () {
              _toggleFavorite(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF4ECDC4)),
            onPressed: () {
              _shareItem(item);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: item.color != null
                      ? Color(int.parse(item.color!.replaceFirst('#', '0xFF')))
                          .withValues(alpha: 0.1)
                      : const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    item.icon ?? '📦',
                    style: const TextStyle(fontSize: 60),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(item.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        if (item.isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Low Stock',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (item.hasExpiry) ...[
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expiry Date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateFormat.format(item.expiryDate!),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getExpiryColor(item.expiryStatus),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.daysLeftText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateQuantity(context, -1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                    ),
                    icon: const Icon(Icons.remove),
                    label: const Text('Take Out'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateQuantity(context, 1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: const Color(0xFF2D3436),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Return'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'inside':
        return const Color(0xFF00B894);
      case 'taken':
        return const Color(0xFFFDCB6E);
      case 'used':
        return const Color(0xFF6C5CE7);
      case 'damaged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getExpiryColor(String status) {
    switch (status) {
      case 'expired':
        return Colors.red;
      case 'expiring_soon':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final updatedItem = widget.item.copyWith(
      isFavorite: !widget.item.isFavorite,
    );
    await context.read<ItemProvider>().updateItem(updatedItem);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updateQuantity(BuildContext context, int delta) async {
    final newQuantity = widget.item.quantity + delta;
    if (newQuantity < 0) return;
    
    final updatedItem = widget.item.copyWith(
      quantity: newQuantity,
      status: newQuantity == 0 ? 'taken' : 'inside',
    );
    await context.read<ItemProvider>().updateItem(updatedItem);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delta > 0 
              ? 'Returned 1 ${widget.item.unit}'
              : 'Took out 1 ${widget.item.unit}'
          ),
          backgroundColor: const Color(0xFF4ECDC4),
        ),
      );
    }
  }

  void _shareItem(ItemModel item) {
    final shareText = '''
${item.name}
${item.description ?? ''}
Quantity: ${item.quantity} ${item.unit}
${item.hasExpiry ? 'Expiry: ${DateFormat('MMM dd, yyyy').format(item.expiryDate!)}' : ''}
${item.brand != null ? 'Brand: ${item.brand}' : ''}
Shared from Smart Cabinet Finder
''';
    Share.share(shareText);
  }
}