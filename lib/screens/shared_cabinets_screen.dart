// lib/screens/shared_cabinets_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import 'cabinet_detail_screen.dart';

class SharedCabinetsScreen extends StatelessWidget {
  const SharedCabinetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cabinetProvider = context.watch<CabinetProvider>();
    final authProvider = context.watch<AuthProvider>();
    
    final sharedCabinets = cabinetProvider.sharedCabinets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Cabinets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              cabinetProvider.reloadCabinets();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: sharedCabinets.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No cabinets shared with you yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'When someone shares a cabinet, it will appear here',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sharedCabinets.length,
              itemBuilder: (context, index) {
                final cabinet = sharedCabinets[index];
                final permission = cabinet.getPermission(authProvider.userId);
                final textColor = Theme.of(context).colorScheme.onSurface;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          cabinet.icon ?? '🗄️', 
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    title: Text(
                      cabinet.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      '${cabinet.itemCount} items • ${cabinet.location ?? 'No location'}',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.55),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPermissionColor(permission),
                        borderRadius: BorderRadius.circular(8),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CabinetDetailScreen(
                            cabinetId: cabinet.id!,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
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