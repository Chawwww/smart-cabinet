// lib/screens/cabinet_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/share_cabinet_screen.dart';

class CabinetDetailScreen extends StatefulWidget {
  final String cabinetId;
  const CabinetDetailScreen({super.key, required this.cabinetId});

  @override
  State<CabinetDetailScreen> createState() => _CabinetDetailScreenState();
}

class _CabinetDetailScreenState extends State<CabinetDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final cabinetProvider = context.watch<CabinetProvider>();
    final authProvider = context.watch<AuthProvider>();
    
    final cabinet = cabinetProvider.getCabinetById(widget.cabinetId);
    if (cabinet == null) {
      return const Scaffold(
        body: Center(child: Text('Cabinet not found')),
      );
    }

    final isOwner = cabinet.userId == authProvider.userId;
    final permission = cabinet.getPermission(authProvider.userId);

    return Scaffold(
      appBar: AppBar(
        title: Text(cabinet.name),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabinet info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(cabinet.icon ?? '🗄️', style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
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
                                  cabinet.location!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (cabinet.description != null)
                      Text(cabinet.description!),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.inventory_2, size: 16),
                        const SizedBox(width: 4),
                        Text('${cabinet.itemCount} items'),
                        const SizedBox(width: 16),
                        const Icon(Icons.folder, size: 16),
                        const SizedBox(width: 4),
                        Text('${cabinet.boxCount} boxes'),
                      ],
                    ),
                    
                    // ✅ Shared users count
                    if (isOwner && cabinet.sharedWith.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
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
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Items in cabinet...
            const SizedBox(height: 16),
            const Text(
              'Items in this cabinet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // ... rest of your items list
          ],
        ),
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