// lib/screens/menu_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';
import '../l10n/app_localizations.dart';

import 'profile_screen.dart';
import 'login_screen.dart';
import 'category_screen.dart';
import 'add_edit_item_screen.dart';
import 'ai_chat_screen.dart';
import 'custom_fields_screen.dart';
import 'help_support_screen.dart';
import 'medicine_info_screen.dart';
import 'language_selector_screen.dart';
import 'shared_cabinets_screen.dart';
import 'smart_cabinet_control_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        authProvider.refreshUserData();
      }
    });
  }

  // ── Sync ─────────────────────────────────────────────
  Future<void> _syncInventory(BuildContext context) async {
    context.read<ItemProvider>().reloadItems();
    context.read<CategoryProvider>().loadCategories();
    context.read<CabinetProvider>()
      ..loadCabinets()
      ..loadBoxes();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Inventory synced'),
        backgroundColor: Color(0xFF00B894)));
  }

  // ── Reports dialog ────────────────────────────────────
  void _showReports(BuildContext context) {
    final ip = context.read<ItemProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('📊 Inventory Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportRow('Total Items',    '${ip.totalItems}'),
            _reportRow('Expired',        '${ip.expiredItems.length}'),
            _reportRow('Expiring Soon',  '${ip.expiringSoonItems.length}'),
            _reportRow('Low Stock',      '${ip.lowStockItems.length}'),
            _reportRow('Out of Stock',   '${ip.outOfStockItems.length}'),
            _reportRow('Favourites',     '${ip.favoriteItems.length}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF636E72))),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  // ── Tags ──────────────────────────────────────────────
  void _manageTags(BuildContext context) {
    final ip = context.read<ItemProvider>();
    final tags = ip.items
        .expand((i) => i.tags)
        .toSet()
        .toList()
      ..sort();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🏷️ All Tags'),
        content: tags.isEmpty
            ? const Text('No tags yet.')
            : SizedBox(
                width: double.maxFinite,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map((t) => Chip(
                            label: Text(t),
                            backgroundColor: const Color(0xFF4ECDC4)
                                .withValues(alpha: 0.15),
                          ))
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Bulk import ───────────────────────────────────────
  void _showBulkImport(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('📥 Bulk Import'),
        content: const Text(
            'Bulk import from CSV is coming soon.\n\n'
            'For now, add items one by one from the Items tab, '
            'or use AI Auto-Fill to speed up the process.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  // ── Sign out ──────────────────────────────────────────
  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
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
    final languageProvider = context.watch<LanguageProvider>();
    final cabinetProvider = context.watch<CabinetProvider>();
    final user = authProvider.currentUser;
    final appLocalizations = AppLocalizations.of(context)!;

    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);

    debugPrint('🔍 Menu Screen - isLoggedIn: ${authProvider.isLoggedIn}');
    debugPrint('🔍 Menu Screen - user: ${user?.name}, ${user?.email}');

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Profile card ──────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        user != null && user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : authProvider.isLoggedIn 
                                ? 'U'
                                : 'G',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? (authProvider.isLoggedIn ? 'User' : 'Guest User'),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor),
                        ),
                        Text(
                          user?.email ?? (authProvider.isLoggedIn ? 'Logged in' : 'Not logged in'),
                          style: TextStyle(
                              fontSize: 14, color: subColor),
                        ),
                        if (authProvider.isLoggedIn && user?.avatar != null)
                          Text(
                            '✓ Google Account',
                            style: TextStyle(
                                fontSize: 12, 
                                color: const Color(0xFF4ECDC4),
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                  if (!authProvider.isLoggedIn)
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          minimumSize: const Size(80, 36)),
                      child: const Text('Login'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Menu items ─────────────────────────────
          _item(context, Icons.person_outline, appLocalizations.profile,
              onTap: () {
                if (authProvider.isLoggedIn) {
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please login first')));
                }
              }),

          _item(context, Icons.category_outlined, appLocalizations.manageCategories,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CategoryScreen()))),

          _item(context, Icons.add_box_outlined, appLocalizations.addNewItem,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AddEditItemScreen()))),

          _item(context, Icons.auto_awesome_outlined, appLocalizations.aiAssistant,
              badge: 'AI',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AIChatScreen()))),

          _item(context, Icons.medication_outlined, appLocalizations.medicineInfo,
              badge: '💊',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MedicineInfoScreen()),
              )),

          _item(context, Icons.assessment_outlined, appLocalizations.reports,
              onTap: () => _showReports(context)),

          _item(context, Icons.cloud_upload_outlined, appLocalizations.bulkImport,
              onTap: () => _showBulkImport(context)),

          _item(context, Icons.tune_outlined, appLocalizations.customFields,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CustomFieldsScreen()))),

          _item(context, Icons.local_offer_outlined, appLocalizations.manageTags,
              onTap: () => _manageTags(context)),

          _item(context, Icons.sync_outlined, appLocalizations.syncInventory,
              onTap: () => _syncInventory(context)),

          _item(context, Icons.help_outline, appLocalizations.helpSupport,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const HelpSupportScreen()))),

          // ── ✅ SMART CABINET CONTROL ──────────────
          _item(context, Icons.bluetooth, 'Smart Cabinet Control',
              badge: '🔵',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SmartCabinetControlScreen(),
                ),
              ),
          ),

          // ── ✅ SHARED CABINETS SECTION ──────────────
          _item(context, Icons.people_outline, 'Shared Cabinets',
              subtitle: '${cabinetProvider.sharedCabinets.length} cabinets shared with you',
              badge: cabinetProvider.sharedCabinets.isNotEmpty 
                  ? '${cabinetProvider.sharedCabinets.length}' 
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SharedCabinetsScreen(),
                ),
              ),
          ),

          const Divider(),

          // ── Language Selector ──────────────────────
          _item(
            context, 
            Icons.language, 
            appLocalizations.language,
            subtitle: '${languageProvider.getCurrentLanguageFlag()} ${languageProvider.getCurrentLanguageName()}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LanguageSelectorScreen(),
              ),
            ),
          ),

          // Dark mode toggle
          ListTile(
            leading: Icon(
              themeProvider.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: textColor.withValues(alpha: 0.7),
            ),
            title: Text('Dark Mode',
                style: TextStyle(color: textColor)),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
              activeColor: const Color(0xFF4ECDC4),
            ),
            onTap: () => themeProvider.toggleTheme(),
          ),

          const Divider(),

          if (authProvider.isLoggedIn)
            _item(context, Icons.logout, appLocalizations.logout,
                color: Colors.red,
                onTap: () => _signOut(context)),

          const SizedBox(height: 16),
          Text('Smart Cabinet Finder v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: subColor)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title, {
    String? badge,
    String? subtitle,
    Color? color,
    VoidCallback? onTap,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.4);

    return ListTile(
      leading:
          Icon(icon, color: color ?? textColor.withValues(alpha: 0.75)),
      title: Text(title,
          style: TextStyle(color: color ?? textColor)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: subColor,
              ),
            )
          : null,
      trailing: badge != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: subColor),
              ],
            )
          : Icon(Icons.chevron_right, size: 20, color: subColor),
      onTap: onTap,
    );
  }
}