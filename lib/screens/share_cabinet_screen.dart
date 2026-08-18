// lib/screens/share_cabinet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cabinet_share_service.dart';

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
  final _bulkEmailsController = TextEditingController();
  String _selectedPermission = 'view';
  bool _isLoading = false;
  List<Map<String, dynamic>> _sharedUsers = [];
  List<Map<String, dynamic>> _pendingInvites = [];
  int _selectedTab = 0; // 0: Add User, 1: Pending Invites

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _bulkEmailsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadSharedUsers(),
      _loadPendingInvites(),
    ]);
  }

  Future<void> _loadSharedUsers() async {
    final provider = context.read<CabinetProvider>();
    final users = await provider.getCabinetUsers(widget.cabinetId);
    setState(() => _sharedUsers = users);
  }

  Future<void> _loadPendingInvites() async {
    final provider = context.read<CabinetProvider>();
    final invites = await provider.listPendingInvites(widget.cabinetId);
    setState(() => _pendingInvites = invites);
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
        await _loadData();
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

  /// Share cabinet with multiple users at once (comma-separated emails)
  Future<void> _bulkShare() async {
    final input = _bulkEmailsController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter emails separated by commas or newlines')),
      );
      return;
    }

    // Parse emails from comma or newline separated input
    final emails = input
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.contains('@'))
        .toList();

    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid emails found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await context.read<CabinetProvider>().bulkShareCabinet(
            cabinetId: widget.cabinetId,
            emails: emails,
            permission: _selectedPermission,
          );

      final successCount = result['successCount'] as int? ?? 0;
      final totalCount = emails.length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Shared with $successCount of $totalCount user(s)',
          ),
          backgroundColor:
              successCount == totalCount ? Colors.green : Colors.orange,
        ),
      );

      if (successCount > 0) {
        _bulkEmailsController.clear();
        await _loadData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _createInvite() async {
    setState(() => _isLoading = true);
    try {
      final link = await CabinetShareService.instance.createInvite(
        cabinetId: widget.cabinetId,
        permission: _selectedPermission,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Share invitation'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            QrImageView(data: link, size: 220),
            const SizedBox(height: 12),
            const Text(
                'Scan to view this cabinet securely in a web browser. The app is not required.',
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('The invite expires in 7 days and can be used once.',
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            SelectableText(link, textAlign: TextAlign.center),
          ]),
          actions: [
            TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (dialogContext.mounted)
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Invite link copied')));
                },
                child: const Text('Copy link')),
            TextButton(
                onPressed: () => Share.share('Join my Smart Cabinet: $link'),
                child: const Text('Share')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done')),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not create invite: $error'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _updatePermission(
      String userId, String userName, String newPermission) async {
    final success = await context.read<CabinetProvider>().updatePermission(
          cabinetId: widget.cabinetId,
          userId: userId,
          newPermission: newPermission,
        );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Updated $userName\'s permission to ${_getPermissionLabel(newPermission)}'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    }
  }

  /// Revoke a pending invitation
  Future<void> _revokePendingInvite(String inviteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke Invitation'),
        content: const Text('Are you sure you want to revoke this invitation?'),
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

    final success = await context.read<CabinetProvider>().revokePendingInvite(
          cabinetId: widget.cabinetId,
          inviteId: inviteId,
        );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Invitation revoked'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isOwner = _sharedUsers
        .any((u) => u['isOwner'] == true && u['id'] == authProvider.userId);

    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                                    (user['name'] as String? ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  user['name'] ?? 'Unknown',
                                  style:
                                      TextStyle(fontSize: 14, color: textColor),
                                ),
                                subtitle: Text(
                                  user['isOwner']
                                      ? '👑 Owner'
                                      : '${_getPermissionLabel(user['permission'])}',
                                  style:
                                      TextStyle(fontSize: 12, color: subColor),
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

    // Owner view - full management with tabs
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Cabinet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildOwnerView(textColor, subColor),
    );
  }

  /// Build the owner view with tabbed interface
  Widget _buildOwnerView(Color textColor, Color subColor) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  label: 'Add User',
                  icon: Icons.person_add,
                  isSelected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  label: 'Bulk Share',
                  icon: Icons.group,
                  isSelected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                  textColor: textColor,
                  badge: null,
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  label: 'Pending Invites',
                  icon: Icons.mail_outline,
                  isSelected: _selectedTab == 2,
                  onTap: () => setState(() => _selectedTab = 2),
                  textColor: textColor,
                  badge: _pendingInvites.isNotEmpty
                      ? _pendingInvites.length.toString()
                      : null,
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  label: 'Users',
                  icon: Icons.people,
                  isSelected: _selectedTab == 3,
                  onTap: () => setState(() => _selectedTab = 3),
                  textColor: textColor,
                  badge: (_sharedUsers.length - 1)
                      .toString(), // Exclude owner from count
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildTabContent(textColor, subColor),
          ),
        ),
      ],
    );
  }

  /// Build individual tab button
  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? const Color(0xFF4ECDC4) : Colors.grey,
                    size: 24,
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? const Color(0xFF4ECDC4) : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build tab content based on selected tab
  Widget _buildTabContent(Color textColor, Color subColor) {
    switch (_selectedTab) {
      case 0:
        return _buildAddUserTab(textColor, subColor);
      case 1:
        return _buildBulkShareTab(textColor, subColor);
      case 2:
        return _buildPendingInvitesTab(textColor, subColor);
      case 3:
        return _buildUsersTab(textColor, subColor);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Tab 0: Add single user
  Widget _buildAddUserTab(Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Text(
          'Share with one user',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          enabled: !_isLoading,
          decoration: const InputDecoration(
            hintText: 'Enter user email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Permission:'),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedPermission,
                items: const [
                  DropdownMenuItem(value: 'view', child: Text('👁️ View Only')),
                  DropdownMenuItem(value: 'edit', child: Text('✏️ Can Edit')),
                  DropdownMenuItem(value: 'admin', child: Text('👑 Admin')),
                ],
                onChanged: (v) => setState(() => _selectedPermission = v!),
                underline: const SizedBox.shrink(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _share,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Share Cabinet', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _createInvite,
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Create Invite Link/QR Code'),
        ),
      ],
    );
  }

  /// Tab 1: Bulk share with multiple users
  Widget _buildBulkShareTab(Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share with multiple users',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter emails separated by commas or newlines',
          style: TextStyle(fontSize: 13, color: subColor),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bulkEmailsController,
          enabled: !_isLoading,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'user1@example.com\nuser2@example.com\nuser3@example.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.list),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Permission:'),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedPermission,
                items: const [
                  DropdownMenuItem(value: 'view', child: Text('👁️ View Only')),
                  DropdownMenuItem(value: 'edit', child: Text('✏️ Can Edit')),
                  DropdownMenuItem(value: 'admin', child: Text('👑 Admin')),
                ],
                onChanged: (v) => setState(() => _selectedPermission = v!),
                underline: const SizedBox.shrink(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _bulkShare,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Share with All', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  /// Tab 2: Manage pending invitations
  Widget _buildPendingInvitesTab(Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Invitations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        if (_pendingInvites.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No pending invitations',
                style: TextStyle(color: subColor),
              ),
            ),
          )
        else
          ..._pendingInvites.map((invite) {
            final expiresAt = DateTime.fromMillisecondsSinceEpoch(
              invite['expiresAt'] as int? ?? 0,
            );
            final isExpired = invite['isExpired'] as bool? ?? false;
            final permission = invite['permission'] as String? ?? 'view';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Permission: ${_getPermissionLabel(permission)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Expires: ${expiresAt.toLocal().toString().split('.')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpired ? Colors.red : subColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isExpired)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            _revokePendingInvite(invite['id'] as String),
                        tooltip: 'Revoke invitation',
                      ),
                    if (isExpired)
                      Chip(
                        label: const Text('Expired'),
                        backgroundColor: Colors.red.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  /// Tab 3: Manage current users
  Widget _buildUsersTab(Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users with Access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        ..._sharedUsers
            .map((user) => Card(
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
                        if (!(user['isOwner'] ?? false)) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButton<String>(
                              value: user['permission'] ?? 'view',
                              items: const [
                                DropdownMenuItem(
                                    value: 'view', child: Text('👁️')),
                                DropdownMenuItem(
                                    value: 'edit', child: Text('✏️')),
                                DropdownMenuItem(
                                    value: 'admin', child: Text('👑')),
                              ],
                              onChanged: (newPerm) {
                                if (newPerm != null) {
                                  _updatePermission(
                                    user['id'],
                                    user['name'] ?? 'Unknown',
                                    newPerm,
                                  );
                                }
                              },
                              underline: const SizedBox.shrink(),
                              icon: const Icon(Icons.arrow_drop_down, size: 18),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.red, size: 18),
                            onPressed: () => _revokeAccess(
                              user['id'],
                              user['name'] ?? 'Unknown',
                            ),
                            tooltip: 'Revoke access',
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECDC4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Owner',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ))
            .toList(),
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
    );
  }

  String _getPermissionLabel(String? permission) {
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

  Color _getPermissionColor(String? permission) {
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
