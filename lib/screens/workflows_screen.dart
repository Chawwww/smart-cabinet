import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import 'add_edit_item_screen.dart';

class WorkflowsScreen extends StatelessWidget {
  const WorkflowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: Use Theme colors — no more hardcoded light-mode colours
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Workflows',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),
          _buildWorkflowCard(
            context: context,
            icon: Icons.inventory_2,
            title: 'Stock Counts',
            description:
                'Count and verify your inventory. Stock counts help you track accurate quantities and keep records up to date.',
            color: const Color(0xFF4ECDC4),
            textColor: textColor,
            subColor: subColor,
            onTap: () => _showComingSoon(context, 'Stock Counts'),
          ),
          const SizedBox(height: 16),
          _buildWorkflowCard(
            context: context,
            icon: Icons.list_alt,
            title: 'Pick Lists',
            description:
                'Easily request items for pickup. Create a list, add items, and assign it to a user for review.',
            color: const Color(0xFF45B7D1),
            textColor: textColor,
            subColor: subColor,
            onTap: () => _showComingSoon(context, 'Pick Lists'),
          ),
          const SizedBox(height: 16),
          _buildWorkflowCard(
            context: context,
            icon: Icons.shopping_cart,
            title: 'Purchase Orders',
            description:
                'Simplify your procurement process by creating, managing and tracking purchase orders.',
            color: const Color(0xFF6C5CE7),
            textColor: textColor,
            subColor: subColor,
            onTap: () => _showComingSoon(context, 'Purchase Orders'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context: context,
                  icon: Icons.add,
                  title: 'Add Items',
                  subtitle: 'NEW',
                  color: const Color(0xFF00B894),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddEditItemScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  context: context,
                  icon: Icons.file_download,
                  title: 'Receive Items',
                  subtitle: 'NEW',
                  color: const Color(0xFFFDCB6E),
                  onTap: () => _showComingSoon(context, 'Receive Items'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quick stats strip
          _buildStatsStrip(context, textColor, subColor),
        ],
      ),
    );
  }

  Widget _buildWorkflowCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color textColor,
    required Color subColor,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: TextStyle(fontSize: 13, color: subColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: subColor.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsStrip(
      BuildContext context, Color textColor, Color subColor) {
    final itemProvider = context.watch<ItemProvider>();
    return Row(
      children: [
        _statChip(context, '${itemProvider.totalItems}', 'Total',
            const Color(0xFF4ECDC4), textColor, subColor),
        const SizedBox(width: 8),
        _statChip(context, '${itemProvider.expiredItems.length}', 'Expired',
            Colors.red, textColor, subColor),
        const SizedBox(width: 8),
        _statChip(context, '${itemProvider.lowStockItems.length}', 'Low Stock',
            Colors.orange, textColor, subColor),
      ],
    );
  }

  Widget _statChip(BuildContext context, String value, String label,
      Color color, Color textColor, Color subColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: subColor)),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon!')),
    );
  }
}