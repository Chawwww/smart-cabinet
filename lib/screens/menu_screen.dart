import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';

import 'profile_screen.dart';
import 'login_screen.dart';
import 'category_screen.dart';
import 'add_edit_item_screen.dart';
import 'ai_chat_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  // ── Sync: reload all data from Firestore ──────────────────
  Future<void> _syncInventory(BuildContext context) async {
    context.read<ItemProvider>().loadItems();
    context.read<CategoryProvider>().loadCategories();
    context.read<CabinetProvider>()
      ..loadCabinets()
      ..loadBoxes();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Inventory synced successfully'),
        backgroundColor: Color(0xFF00B894),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Reports: simple summary dialog ────────────────────────
  void _showReports(BuildContext context) {
    final itemProvider = context.read<ItemProvider>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('📊 Inventory Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reportRow('Total Items', '${itemProvider.totalItems}'),
            _reportRow('Expired', '${itemProvider.expiredItems.length}'),
            _reportRow('Expiring Soon', '${itemProvider.expiringSoonItems.length}'),
            _reportRow('Low Stock', '${itemProvider.lowStockItems.length}'),
            _reportRow('Out of Stock', '${itemProvider.outOfStockItems.length}'),
            _reportRow('Favourites', '${itemProvider.favoriteItems.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF636E72))),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  // ── Tags manager ──────────────────────────────────────────
  void _manageTags(BuildContext context) {
    final itemProvider = context.read<ItemProvider>();
    final allTags = itemProvider.items
        .expand((item) => item.tags)
        .toSet()
        .toList()
      ..sort();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🏷️ All Tags'),
        content: allTags.isEmpty
            ? const Text('No tags found. Add tags when creating items.')
            : SizedBox(
                width: double.maxFinite,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          backgroundColor:
                              const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                        ),
                      )
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Bulk import placeholder ────────────────────────────────
  void _showBulkImport(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('📥 Bulk Import'),
        content: const Text(
          'Bulk import allows you to add many items at once from a CSV file.\n\n'
          'This feature is coming soon. You can add items one by one from the Items screen for now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Custom fields placeholder ──────────────────────────────
  void _showCustomFields(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚙️ Custom Fields'),
        content: const Text(
          'Custom fields let you add extra attributes to your items, '
          'like serial numbers, purchase prices, or warranty dates.\n\n'
          'These are already supported when adding/editing items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // ── Help & Support ────────────────────────────────────────
  Future<void> _openHelp(BuildContext context) async {
    final uri = Uri.parse('https://firebase.google.com/docs');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open help page')),
        );
      }
    }
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> _signOut(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authProvider.logout();
      if (context.mounted) {
        // FIX 2: Clear entire stack and go to Login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.currentUser;

    // FIX 1: Use Theme colors for dark mode support
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Container(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile card ─────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        user != null && user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Guest User',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          user?.email ?? 'Not logged in',
                          style: TextStyle(fontSize: 14, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  if (!authProvider.isLoggedIn)
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        minimumSize: const Size(80, 36),
                      ),
                      child: const Text('Login'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── FIX 4: Every menu item now has a real action ──
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: 'User Profile',
            onTap: () {
              if (authProvider.isLoggedIn) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please login first')),
                );
              }
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.category_outlined,
            title: 'Manage Categories',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.add_box_outlined,
            title: 'Add New Item',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.auto_awesome_outlined,
            title: 'AI Assistant',
            badge: 'AI',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AIChatScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.assessment_outlined,
            title: 'Reports',
            onTap: () => _showReports(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.cloud_upload_outlined,
            title: 'Bulk Import',
            onTap: () => _showBulkImport(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.settings_outlined,
            title: 'Custom Fields',
            onTap: () => _showCustomFields(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.local_offer_outlined,
            title: 'Manage Tags',
            onTap: () => _manageTags(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.sync_outlined,
            title: 'Sync Inventory',
            onTap: () => _syncInventory(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () => _openHelp(context),
          ),

          const Divider(),

          // ── Dark mode toggle ──────────────────────
          _buildMenuItem(
            context,
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
              activeColor: const Color(0xFF4ECDC4),
            ),
            onTap: () => themeProvider.toggleTheme(),
          ),

          const Divider(),

          if (authProvider.isLoggedIn)
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Sign Out',
              color: Colors.red,
              onTap: () => _signOut(context),
            ),

          const SizedBox(height: 16),
          Text(
            'Version 1.0.0',
            style: TextStyle(fontSize: 12, color: subColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? badge,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color ?? textColor.withValues(alpha: 0.75)),
      title: Text(
        title,
        style: TextStyle(color: color ?? textColor),
      ),
      trailing: badge != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4),
                    borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 20, color: textColor.withValues(alpha: 0.4)),
              ],
            )
          : trailing ??
              Icon(Icons.chevron_right,
                  size: 20, color: textColor.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }
}