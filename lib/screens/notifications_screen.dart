import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../providers/item_provider.dart';
import 'item_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();

    // Use theme-aware colors
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    final expiredItems = itemProvider.expiredItems;
    final expiringItems = itemProvider.expiringSoonItems;
    final lowStockItems = itemProvider.lowStockItems;

    final hasNotifications =
        expiredItems.isNotEmpty || expiringItems.isNotEmpty || lowStockItems.isNotEmpty;

    // FIX: Use Scaffold so the screen has proper height constraints,
    // allowing Expanded/ListView to size correctly inside it.
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  if (hasNotifications)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${expiredItems.length + expiringItems.length + lowStockItems.length}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────
            Expanded(
              child: itemProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                      ),
                    )
                  : !hasNotifications
                      ? _buildEmpty(subColor)
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          children: [
                            if (expiredItems.isNotEmpty)
                              _buildSection(
                                context: context,
                                title: 'Expired Items',
                                icon: Icons.warning_amber_rounded,
                                color: Colors.red,
                                items: expiredItems,
                              ),
                            if (expiringItems.isNotEmpty)
                              _buildSection(
                                context: context,
                                title: 'Expiring Soon',
                                icon: Icons.timer_outlined,
                                color: Colors.orange,
                                items: expiringItems,
                              ),
                            if (lowStockItems.isNotEmpty)
                              _buildSection(
                                context: context,
                                title: 'Low Stock',
                                icon: Icons.inventory_2_outlined,
                                color: const Color(0xFFFDCB6E),
                                items: lowStockItems,
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color subColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 80, color: subColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'All good!',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600, color: subColor),
          ),
          const SizedBox(height: 8),
          Text(
            'No expired, expiring, or low-stock items',
            style: TextStyle(fontSize: 14, color: subColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required List<ItemModel> items,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '$title (${items.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),

        // Item cards
        ...items.map((item) => _buildItemCard(context, item, color)),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildItemCard(
      BuildContext context, ItemModel item, Color accentColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(item: item),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    item.icon ?? '📦',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + detail
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.hasExpiry
                          ? item.daysLeftText
                          : 'Stock: ${item.quantity} ${item.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.expiryStatus == 'expired'
                      ? 'Expired'
                      : item.expiryStatus == 'expiring_soon'
                          ? 'Soon'
                          : 'Low Stock',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}