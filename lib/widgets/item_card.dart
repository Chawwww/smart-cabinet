import 'package:flutter/material.dart';
import '../models/item_model.dart';

// SUPERVISOR REQ 5: Item images displayed directly for easier identification
class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const ItemCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.5);

    Color accent;
    try {
      accent = item.color != null
          ? Color(int.parse(item.color!.replaceFirst('#', '0xFF')))
          : const Color(0xFF4ECDC4);
    } catch (_) {
      accent = const Color(0xFF4ECDC4);
    }

    final hasPhoto = item.imageUrls.isNotEmpty &&
        item.imageUrls.first.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP: photo or emoji ─────────────────────
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  // Photo or emoji background
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14)),
                    child: SizedBox.expand(
                      child: hasPhoto
                          ? Image.network(
                              item.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _emojiBox(accent, isDark),
                              loadingBuilder: (_, child, prog) {
                                if (prog == null) return child;
                                return _emojiBox(accent, isDark);
                              },
                            )
                          : _emojiBox(accent, isDark),
                    ),
                  ),

                  // Favourite heart
                  if (item.isFavorite)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite,
                            color: Colors.red, size: 12),
                      ),
                    ),

                  // Expiry / stock badge
                  Positioned(
                    top: 6, right: 6,
                    child: _badge(),
                  ),

                  // Taken ribbon
                  if (item.status == 'taken')
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        color: Colors.black.withValues(alpha: 0.55),
                        child: const Text('TAKEN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                      ),
                    ),
                ],
              ),
            ),

            // ── BOTTOM: info ────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name
                    Text(item.name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),

                    // Brand (if available)
                    if (item.brand != null && item.brand!.isNotEmpty)
                      Text(item.brand!,
                          style: TextStyle(
                              fontSize: 10,
                              color: subColor,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),

                    // SUPERVISOR REQ 1: Quantity display with initial qty
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        // Quantity pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isOutOfStock
                                ? Colors.red.withValues(alpha: 0.12)
                                : item.isLowStock
                                    ? Colors.orange
                                        .withValues(alpha: 0.12)
                                    : accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${item.quantity}/${item.initialQuantity} ${item.unit}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: item.isOutOfStock
                                  ? Colors.red
                                  : item.isLowStock
                                      ? Colors.orange
                                      : accent,
                            ),
                          ),
                        ),

                        // Expiry days
                        if (item.hasExpiry && item.daysLeftText.isNotEmpty)
                          Text(
                            item.isExpired
                                ? 'EXP'
                                : item.isExpiringSoon
                                    ? item.daysLeftText
                                        .replaceAll(' days left', 'd')
                                        .replaceAll(' left', '')
                                    : '',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: item.isExpired
                                  ? Colors.red
                                  : Colors.orange,
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

  Widget _emojiBox(Color accent, bool isDark) => Container(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
        child: Center(
          child: Text(item.icon ?? '📦',
              style: const TextStyle(fontSize: 40)),
        ),
      );

  Widget _badge() {
    String label;
    Color color;
    if (item.isExpired) {
      label = 'EXP';
      color = Colors.red;
    } else if (item.isExpiringSoon) {
      label = 'SOON';
      color = Colors.orange;
    } else if (item.isOutOfStock) {
      label = 'EMPTY';
      color = Colors.red;
    } else if (item.isLowStock) {
      label = 'LOW';
      color = const Color(0xFFFDCB6E);
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }
}