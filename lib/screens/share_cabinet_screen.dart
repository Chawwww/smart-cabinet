// lib/screens/share_cabinet_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';

class ShareCabinetScreen extends StatefulWidget {
  final String cabinetId;
  final String cabinetName;

  const ShareCabinetScreen({
    super.key,
    required this.cabinetId,
    required this.cabinetName,
  });

  @override
  State<ShareCabinetScreen> createState() => _ShareCabinetScreenState();
}

class _ShareCabinetScreenState extends State<ShareCabinetScreen> {
  final _emailController = TextEditingController();
  String _selectedPermission = 'view';
  bool _isLoading = false;
  List<Map<String, dynamic>> _sharedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadSharedUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSharedUsers() async {
    final provider = context.read<CabinetProvider>();
    final users = await provider.getCabinetUsers(widget.cabinetId);
    setState(() => _sharedUsers = users);
  }

  Future<void> _share() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await context.read<CabinetProvider>().shareCabinet(
        cabinetId: widget.cabinetId,
        userEmail: email,
        permission: _selectedPermission,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Cabinet shared with $email'),
            backgroundColor: Colors.green,
          ),
        );
        _emailController.clear();
        await _loadSharedUsers();
      } else {
        final error = context.read<CabinetProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to share cabinet'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _revokeAccess(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text('Remove $userName\'s access to this cabinet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await context.read<CabinetProvider>().revokeAccess(
      cabinetId: widget.cabinetId,
      userId: userId,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Removed $userName\'s access'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadSharedUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isOwner = _sharedUsers.any((u) => u['isOwner'] == true && u['id'] == authProvider.userId);
    
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);

    // If not owner, show read-only view
    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cabinet Access'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'You are a shared user',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only the owner can manage sharing settings.',
                  style: TextStyle(color: subColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_sharedUsers.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Users with access:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._sharedUsers.map((user) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: user['isOwner'] 
                                  ? const Color(0xFF4ECDC4) 
                                  : Colors.grey,
                              radius: 14,
                              child: Text(
                                (user['name'] as String? ?? '?')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              user['name'] ?? 'Unknown',
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                            subtitle: Text(
                              user['isOwner'] ? '👑 Owner' : '${_getPermissionLabel(user['permission'])}',
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Owner view - full management
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Cabinet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabinet Info ────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.cabin, color: Color(0xFF4ECDC4), size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.cabinetName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '${_sharedUsers.length} user(s) have access',
                            style: TextStyle(fontSize: 13, color: subColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Add User Section ────────────────────────
            Text(
              'Add User',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Enter user email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedPermission,
                  items: const [
                    DropdownMenuItem(value: 'view', child: Text('👁️ View')),
                    DropdownMenuItem(value: 'edit', child: Text('✏️ Edit')),
                    DropdownMenuItem(value: 'admin', child: Text('👑 Admin')),
                  ],
                  onChanged: (v) => setState(() => _selectedPermission = v!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _share,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Share Cabinet'),
              ),
            ),
            const SizedBox(height: 24),

            // ── Users with Access ───────────────────────
            Text(
              'Users with Access',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            ..._sharedUsers.map((user) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user['isOwner']
                      ? const Color(0xFF4ECDC4)
                      : Colors.grey,
                  child: Text(
                    (user['name'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  user['name'] ?? 'Unknown',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  user['email'] ?? '',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPermissionColor(user['permission']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getPermissionLabel(user['permission']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!(user['isOwner'] ?? false))
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => _revokeAccess(
                          user['id'],
                          user['name'] ?? 'Unknown',
                        ),
                      ),
                  ],
                ),
              ),
            )).toList(),

            if (_sharedUsers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No users have access to this cabinet yet.',
                    style: TextStyle(color: subColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getPermissionLabel(String? permission) {
    switch (permission) {
      case 'view': return 'View';
      case 'edit': return 'Edit';
      case 'admin': return 'Admin';
      default: return 'View';
    }
  }

  Color _getPermissionColor(String? permission) {
    switch (permission) {
      case 'view': return const Color(0xFF636E72);
      case 'edit': return const Color(0xFF4ECDC4);
      case 'admin': return const Color(0xFF6C5CE7);
      default: return const Color(0xFF636E72);
    }
  }
}