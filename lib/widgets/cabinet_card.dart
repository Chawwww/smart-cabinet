import 'package:flutter/material.dart';
import '../models/cabinet_model.dart';

class CabinetCard extends StatelessWidget {
  final CabinetModel cabinet;
  final int itemCount;
  final int boxCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const CabinetCard({
    super.key,
    required this.cabinet,
    required this.itemCount,
    required this.boxCount,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = cabinet.color != null
        ? Color(int.parse(cabinet.color!.replaceFirst('#', '0xFF')))
        : const Color(0xFF4ECDC4);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(cabinet.icon ?? '🗄️',
                        style: const TextStyle(fontSize: 40)),
                  ),
                  if (cabinet.isFavorite)
                    const Positioned(
                        top: 8, right: 8,
                        child: Icon(Icons.favorite, color: Colors.red, size: 20)),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      color: color,
                      onPressed: onEdit,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cabinet.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.inventory_2, size: 13, color: subColor),
                      const SizedBox(width: 4),
                      Text('$itemCount items',
                          style: TextStyle(fontSize: 11, color: subColor)),
                      const SizedBox(width: 10),
                      Icon(Icons.folder, size: 13, color: subColor),
                      const SizedBox(width: 4),
                      Text('$boxCount boxes',
                          style: TextStyle(fontSize: 11, color: subColor)),
                    ],
                  ),
                  if (cabinet.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 13, color: subColor),
                        const SizedBox(width: 4),
                        Text(cabinet.location!,
                            style: TextStyle(fontSize: 11, color: subColor)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}