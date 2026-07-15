// lib/screens/cabinet_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/item_provider.dart';
import '../screens/share_cabinet_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
import 'item_detail_screen.dart';
import 'add_edit_item_screen.dart';

class CabinetDetailScreen extends StatefulWidget {
  final String cabinetId;
  const CabinetDetailScreen({super.key, required this.cabinetId});

  @override
  State<CabinetDetailScreen> createState() => _CabinetDetailScreenState();
}

class _CabinetDetailScreenState extends State<CabinetDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cabinetProvider = context.watch<CabinetProvider>();
    final authProvider = context.watch<AuthProvider>();
    final itemProvider = context.watch<ItemProvider>();
    
    final cabinet = cabinetProvider.getCabinetById(widget.cabinetId);
    if (cabinet == null) {
      return const Scaffold(
        body: Center(child: Text('Cabinet not found')),
      );
    }

    final isOwner = cabinet.userId == authProvider.userId;
    final permission = cabinet.getPermission(authProvider.userId);
    final items = itemProvider.items.where((item) => 
      item.cabinetId == cabinet.id
    ).toList();

    // Get boxes for this cabinet
    final boxes = cabinetProvider.getBoxesForCabinet(cabinet.id!);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(cabinet.icon ?? '🗄️', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(cabinet.name),
          ],
        ),
        actions: [
          // ✅ Share Button - AppBar
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Color(0xFF4ECDC4)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShareCabinetScreen(
                    cabinetId: cabinet.id!,
                    cabinetName: cabinet.name,
                  ),
                ),
              ),
              tooltip: 'Share Cabinet',
            ),
          
          // Permission badge in AppBar
          if (!isOwner && cabinet.hasAccess(authProvider.userId))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _getPermissionColor(permission),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getPermissionLabel(permission),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Cabinet Info Card ──
          Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cabinet.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (cabinet.location != null)
                              Text(
                                '📍 ${cabinet.location!}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Favorite icon
                      if (cabinet.isFavorite)
                        const Icon(Icons.favorite, color: Colors.red, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (cabinet.description != null)
                    Text(
                      cabinet.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statChip(Icons.inventory_2, '${items.length} items'),
                      const SizedBox(width: 8),
                      _statChip(Icons.folder, '${boxes.length} boxes'),
                      const SizedBox(width: 8),
                      if (cabinet.location != null)
                        _statChip(Icons.location_on, cabinet.location!),
                    ],
                  ),
                  
                  // ✅ Shared users count
                  if (isOwner && cabinet.sharedWith.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 16, color: Color(0xFF4ECDC4)),
                          const SizedBox(width: 4),
                          Text(
                            'Shared with ${cabinet.sharedWith.length} user(s)',
                            style: const TextStyle(
                              color: Color(0xFF4ECDC4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // ✅ Share button in body (for easier access)
                  if (isOwner)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShareCabinetScreen(
                                cabinetId: cabinet.id!,
                                cabinetName: cabinet.name,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.share_outlined, color: Color(0xFF4ECDC4)),
                          label: const Text(
                            'Share Cabinet',
                            style: TextStyle(color: Color(0xFF4ECDC4)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF4ECDC4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Add Item Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditItemScreen(),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item to this Cabinet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Items Grid ──
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No Items',
                    subtitle: 'This cabinet is empty. Add your first item!',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ItemCard(
                        item: item,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(item: item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Helper Functions ──
  
  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _getPermissionLabel(String permission) {
    switch (permission) {
      case 'view': return 'View Only';
      case 'edit': return 'Edit';
      case 'admin': return 'Admin';
      default: return 'View';
    }
  }

  Color _getPermissionColor(String permission) {
    switch (permission) {
      case 'view': return const Color(0xFF636E72);
      case 'edit': return const Color(0xFF4ECDC4);
      case 'admin': return const Color(0xFF6C5CE7);
      default: return const Color(0xFF636E72);
    }
  }
}

// ── Internal Item Card Widget ──
class _ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);

    // Determine accent color
    Color accent;
    try {
      accent = item.color != null
          ? Color(int.parse(item.color!.replaceFirst('#', '0xFF')))
          : const Color(0xFF4ECDC4);
    } catch (_) {
      accent = const Color(0xFF4ECDC4);
    }

    final hasPhoto = item.imageUrls.isNotEmpty && item.imageUrls.first.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
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
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox.expand(
                      child: hasPhoto
                          ? Image.network(
                              item.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _emojiBox(accent, isDark),
                              loadingBuilder: (_, child, prog) {
                                if (prog == null) return child;
                                return _emojiBox(accent, isDark);
                              },
                            )
                          : _emojiBox(accent, isDark),
                    ),
                  ),
                  // Favorite heart
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
                  // Status badge
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
                    Text(item.name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (item.brand != null && item.brand!.isNotEmpty)
                      Text(item.brand!,
                          style: TextStyle(
                              fontSize: 10,
                              color: subColor,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isOutOfStock
                                ? Colors.red.withValues(alpha: 0.12)
                                : item.isLowStock
                                    ? Colors.orange.withValues(alpha: 0.12)
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