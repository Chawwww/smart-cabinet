import 'package:flutter/material.dart';
import '../models/box_model.dart';

class BoxCard extends StatelessWidget {
  final BoxModel box;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const BoxCard({
    super.key,
    required this.box,
    required this.itemCount,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = box.color != null
        ? Color(int.parse(box.color!.replaceFirst('#', '0xFF')))
        : const Color(0xFF4ECDC4);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(box.icon ?? '📦',
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(box.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$itemCount items · ${box.type}',
                      style: TextStyle(fontSize: 12, color: subColor)),
                  if (box.capacity != null)
                    Text('Capacity: ${box.capacity}',
                        style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              color: const Color(0xFF4ECDC4),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}