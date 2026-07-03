import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';
import 'item_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();

    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.5);

    final expiredItems     = itemProvider.expiredItems;
    final expiringItems    = itemProvider.expiringSoonItems;
    final lowStockItems    = itemProvider.lowStockItems;
    final outOfStockItems  = itemProvider.outOfStockItems;

    final total = expiredItems.length + expiringItems.length +
        lowStockItems.length + outOfStockItems.length;

    final hasNotifications = total > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('Notifications',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const Spacer(),
                  if (hasNotifications)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$total',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────
            Expanded(
              child: itemProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4ECDC4)))
                  : !hasNotifications
                      ? _buildEmpty(subColor)
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          children: [
                            // EXPIRED — most urgent first
                            if (expiredItems.isNotEmpty)
                              _buildSection(
                                context: context,
                                title: '🚫 Expired Items',
                                subtitle:
                                    'Do not use — remove from cabinet',
                                color: Colors.red,
                                icon: Icons.warning_amber_rounded,
                                items: expiredItems,
                                badgeLabel: 'EXPIRED',
                              ),

                            // EXPIRING SOON
                            if (expiringItems.isNotEmpty)
                              _buildSection(
                                context: context,
                                title: '⏰ Expiring Soon',
                                subtitle:
                                    'Use or restock within 7 days',
                                color: Colors.orange,
                                icon: Icons.timer_outlined,
                                items: expiringItems,
                                badgeLabel: 'SOON',
                              ),

                            // OUT OF STOCK
                            if (outOfStockItems.isNotEmpty)
                              _buildSection(
                                context: context,
                                title: '📭 Out of Stock',
                                subtitle: 'Restock needed',
                                color: Colors.red.shade300,
                                icon: Icons.inventory_2_outlined,
                                items: outOfStockItems,
                                badgeLabel: 'EMPTY',
                              ),

                            // LOW STOCK
                            if (lowStockItems.isNotEmpty)
                              _buildSection(
                                context: context,
                                title: '📉 Low Stock',
                                subtitle:
                                    'Running low — consider restocking',
                                color: Colors.orange.shade700,
                                icon: Icons.remove_shopping_cart_outlined,
                                items: lowStockItems,
                                badgeLabel: 'LOW',
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
              size: 80, color: subColor.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text('All good!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: subColor)),
          const SizedBox(height: 8),
          Text('No expired, expiring, or low-stock items',
              style: TextStyle(fontSize: 14, color: subColor),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required List<ItemModel> items,
    required String badgeLabel,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title  (${items.length})',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11, color: subColor)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Item cards
        ...items.map((item) => _buildItemCard(
            context, item, color, badgeLabel)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, ItemModel item,
      Color accentColor, String badgeLabel) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto  = item.imageUrls.isNotEmpty;
    final fmt = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ItemDetailScreen(item: item)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // SUPERVISOR REQ 5: Show item image directly
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52, height: 52,
                  child: hasPhoto
                      ? Image.network(
                          item.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _iconBox(item, accentColor, isDark),
                        )
                      : _iconBox(item, accentColor, isDark),
                ),
              ),
              const SizedBox(width: 12),

              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor)),

                    // SUPERVISOR REQ 1: Clear quantity display
                    Text(
                      'Qty: ${item.quantity} ${item.unit}  '
                      '(Initial: ${item.initialQuantity} ${item.unit})',
                      style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w500),
                    ),

                    // Expiry date if applicable
                    if (item.hasExpiry)
                      Text(
                        item.isExpired
                            ? 'Expired: ${fmt.format(item.expiryDate!)}'
                            : 'Expires: ${fmt.format(item.expiryDate!)} · ${item.daysLeftText}',
                        style: TextStyle(
                            fontSize: 11, color: subColor),
                      ),
                  ],
                ),
              ),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badgeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(ItemModel item, Color accent, bool isDark) {
    return Container(
      color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
      child: Center(
        child: Text(item.icon ?? '📦',
            style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}