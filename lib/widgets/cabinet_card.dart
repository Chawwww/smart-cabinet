// lib/widgets/cabinet_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_model.dart';
import '../providers/auth_provider.dart';
import '../screens/share_cabinet_screen.dart';

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
    final authProvider = context.watch<AuthProvider>();
    final isOwner = cabinet.userId == authProvider.userId;
    final isShared = !isOwner && cabinet.hasAccess(authProvider.userId);
    
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Section ──────────────────────────────
            Container(
              height: 80,
              width: double.infinity,
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
                  
                  // ✅ Share Button - Top Right (only for owner)
                  if (isOwner)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.share_outlined, 
                            color: Color(0xFF4ECDC4), size: 20),
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
                    ),
                  
                  // Edit Button - Top Left (only for owner)
                  if (isOwner)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: color,
                        onPressed: onEdit,
                      ),
                    ),
                  
                  // Favourite Badge
                  if (cabinet.isFavorite)
                    Positioned(
                      top: 8,
                      left: 50,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite, 
                            color: Colors.red, size: 14),
                      ),
                    ),
                  
                  // ✅ Shared Badge
                  if (isShared)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Shared',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // ── Bottom Section ─────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cabinet.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      // Permission badge for shared cabinets
                      if (isShared)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPermissionColor(cabinet.getPermission(authProvider.userId)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getPermissionLabel(cabinet.getPermission(authProvider.userId)),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                  // Show shared users count for owner
                  if (isOwner && cabinet.sharedWith.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 12, color: subColor),
                          const SizedBox(width: 4),
                          Text(
                            '${cabinet.sharedWith.length} shared user(s)',
                            style: TextStyle(fontSize: 10, color: subColor),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPermissionLabel(String permission) {
    switch (permission) {
      case 'view': return 'View';
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