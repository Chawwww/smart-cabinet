// lib/screens/shared_cabinets_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cabinet_share_service.dart';
import 'cabinet_detail_screen.dart';

class SharedCabinetsScreen extends StatefulWidget {
  const SharedCabinetsScreen({super.key});

  @override
  State<SharedCabinetsScreen> createState() => _SharedCabinetsScreenState();
}

class _SharedCabinetsScreenState extends State<SharedCabinetsScreen> {
  bool _cabinetsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load cabinets only once
    if (!_cabinetsLoaded) {
      final cabinetProvider =
          Provider.of<CabinetProvider>(context, listen: false);
      if (cabinetProvider.cabinets.isEmpty) {
        cabinetProvider.loadCabinets();
      }
      _cabinetsLoaded = true;
    }
  }

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
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join invitation',
            onPressed: () => _joinInvitation(context),
          ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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

  Future<void> _joinInvitation(BuildContext context) async {
    final controller = TextEditingController();
    final invite = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join shared cabinet'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Invitation link or code',
            hintText: 'smartcabinet://join?invite=...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Join')),
        ],
      ),
    );
    controller.dispose();
    if (invite == null || invite.trim().isEmpty || !context.mounted) return;
    try {
      await CabinetShareService.instance.acceptInvite(invite);
      if (!context.mounted) return;
      context.read<CabinetProvider>().loadCabinets();
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cabinet added to Shared Cabinets'),
            backgroundColor: Colors.green));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not join invitation: $error'),
            backgroundColor: Colors.red));
    }
  }

  String _getPermissionLabel(String permission) {
    switch (permission) {
      case 'view':
        return 'View Only';
      case 'edit':
        return 'Edit';
      case 'admin':
        return 'Admin';
      default:
        return 'View';
    }
  }

  Color _getPermissionColor(String permission) {
    switch (permission) {
      case 'view':
        return const Color(0xFF636E72);
      case 'edit':
        return const Color(0xFF4ECDC4);
      case 'admin':
        return const Color(0xFF6C5CE7);
      default:
        return const Color(0xFF636E72);
    }
  }
}
