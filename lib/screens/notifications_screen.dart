import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    
    final expiringItems = itemProvider.items
        .where((item) => item.expiryStatus == 'expiring_soon')
        .toList();
    final expiredItems = itemProvider.items
        .where((item) => item.expiryStatus == 'expired')
        .toList();
    final lowStockItems = itemProvider.items
        .where((item) => item.isLowStock)
        .toList();
    
    final hasNotifications = expiringItems.isNotEmpty ||
        expiredItems.isNotEmpty ||
        lowStockItems.isNotEmpty;
    
    return Container(
      color: const Color(0xFFF2FFFF),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 16),
          if (!hasNotifications)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Icon(
                    Icons.notifications_off,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All items are in good condition',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  if (expiredItems.isNotEmpty)
                    _buildNotificationSection(
                      title: 'Expired Items',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      items: expiredItems,
                    ),
                  if (expiringItems.isNotEmpty)
                    _buildNotificationSection(
                      title: 'Expiring Soon',
                      icon: Icons.timer,
                      color: Colors.orange,
                      items: expiringItems,
                    ),
                  if (lowStockItems.isNotEmpty)
                    _buildNotificationSection(
                      title: 'Low Stock Alert',
                      icon: Icons.inventory,
                      color: const Color(0xFFFDCB6E),
                      items: lowStockItems,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection({
    required String title,
    required IconData icon,
    required Color color,
    required List items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title (${items.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  item.icon ?? '📦',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              item.expiryDate != null
                  ? 'Expires: ${item.daysLeftText}'
                  : 'Low stock: ${item.quantity} ${item.unit}',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.expiryStatus == 'expired'
                    ? 'Expired'
                    : item.isLowStock
                        ? 'Low Stock'
                        : 'Warning',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}