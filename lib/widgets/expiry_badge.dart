// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../models/item_model.dart';

class ExpiryBadge extends StatelessWidget {
  final ItemModel item;

  const ExpiryBadge({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    if (!item.hasExpiry) return const SizedBox.shrink();
    
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
