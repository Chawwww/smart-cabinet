import 'package:flutter/material.dart';
import '../models/item_model.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const ItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: item.color != null
                      ? Color(int.parse(item.color!.replaceFirst('#', '0xFF')))
                          .withValues(alpha: 0.1)
                      : const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        item.icon ?? '📦',
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                    if (item.hasExpiry || item.isLowStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildExpiryBadge(),
                      ),
                    if (item.isFavorite)
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    if (item.status == 'taken')
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'TAKEN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3436),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity} ${item.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: item.isLowStock
                                ? Colors.orange
                                : const Color(0xFF636E72),
                            fontWeight: item.isLowStock
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (item.hasExpiry)
                          Text(
                            item.daysLeftText,
                            style: TextStyle(
                              fontSize: 10,
                              color: item.expiryStatus == 'expired'
                                  ? Colors.red
                                  : item.expiryStatus == 'expiring_soon'
                                      ? Colors.orange
                                      : const Color(0xFF636E72),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryBadge() {
    final status = item.expiryStatus;
    Color color;
    String label;
    
    switch (status) {
      case 'expired':
        color = Colors.red;
        label = 'EXPIRED';
        break;
      case 'expiring_soon':
        color = Colors.orange;
        label = 'SOON';
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}