// lib/screens/menu_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';
import '../l10n/l10n.dart';

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
    
    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.syncNow),
        backgroundColor: const Color(0xFF00B894),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Reports dialog ────────────────────────────────────
  void _showReports(BuildContext context) {
    final ip = context.read<ItemProvider>();
    final s = S.of(context);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.assessment, color: Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Text(s.reports),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportRow(s.items, '${ip.totalItems}'),
            _reportRow(s.expired, '${ip.expiredItems.length}'),
            _reportRow(s.expiringSoon, '${ip.expiringSoonItems.length}'),
            _reportRow(s.lowStock, '${ip.lowStockItems.length}'),
            _reportRow(s.outOfStock, '${ip.outOfStockItems.length}'),
            _reportRow(s.favorite, '${ip.favoriteItems.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.close),
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
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  // ── Tags ──────────────────────────────────────────────
  void _manageTags(BuildContext context) {
    final ip = context.read<ItemProvider>();
    final s = S.of(context);
    
    final tags = ip.items
        .expand((i) => i.tags)
        .toSet()
        .toList()
      ..sort();
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.local_offer, color: Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Text(s.manageTags),
          ],
        ),
        content: tags.isEmpty
            ? SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(s.noData, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              )
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
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ))
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }

  // ── Bulk import ───────────────────────────────────────
  void _showBulkImport(BuildContext context) {
    final s = S.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.cloud_upload, color: Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Text(s.bulkImport),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bulk import from CSV is coming soon.\n\n'
              'For now, add items one by one from the Items tab, '
              'or use AI Auto-Fill to speed up the process.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF4ECDC4), size: 18),
                SizedBox(width: 8),
                Text(
                  'CSV support will be available in v1.1.0',
                  style: TextStyle(fontSize: 12, color: Color(0xFF636E72)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }

  // ── Sign out ──────────────────────────────────────────
  Future<void> _signOut(BuildContext context) async {
    final s = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            Text(s.logout),
          ],
        ),
        content: Text('${s.warning}\n\n${s.logout}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(s.logout),
          ),
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
    final s = S.of(context);

    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    debugPrint('🔍 Menu Screen - isLoggedIn: ${authProvider.isLoggedIn}');
    debugPrint('🔍 Menu Screen - user: ${user?.name}, ${user?.email}');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Profile card ────────────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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
                            user?.name ?? (authProvider.isLoggedIn ? s.name : s.guestUser),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            user?.email ?? (authProvider.isLoggedIn ? 'Logged In' : s.guestUser),
                            style: TextStyle(
                              fontSize: 14,
                              color: subColor,
                            ),
                          ),
                          if (authProvider.isLoggedIn && user?.avatar != null)
                            Text(
                              '✓ Google Account',
                              style: TextStyle(
                                fontSize: 12, 
                                color: const Color(0xFF4ECDC4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (authProvider.isLoggedIn && user?.emailVerified == true)
                            Text(
                              '✓ Verified',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!authProvider.isLoggedIn)
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(s.login),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // ── Section: Account ────────────────────────────
            _sectionHeader(s.profile, textColor),
            
            _menuItem(
              context,
              icon: Icons.person_outline,
              title: s.profile,
              onTap: () {
                if (authProvider.isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(s.login),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),

            _menuItem(
              context,
              icon: Icons.category_outlined,
              title: s.manageCategories,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryScreen(),
                ),
              ),
            ),

            const Divider(),
            const SizedBox(height: 8),

            // ── Section: Items ──────────────────────────────
            _sectionHeader(s.items, textColor),

            _menuItem(
              context,
              icon: Icons.add_box_outlined,
              title: s.addNewItem,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditItemScreen(),
                ),
              ),
            ),

            _menuItem(
              context,
              icon: Icons.inventory_2_outlined,
              title: s.manageCategories,
              subtitle: 'Manage your categories',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryScreen(),
                ),
              ),
            ),

            const Divider(),
            const SizedBox(height: 8),

            // ── Section: AI & Features ──────────────────────
            _sectionHeader('AI & Features', textColor),

            _menuItem(
              context,
              icon: Icons.auto_awesome_outlined,
              title: s.aiAssistant,
              badge: '✨ NEW',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AIChatScreen(),
                ),
              ),
            ),

            _menuItem(
              context,
              icon: Icons.medication_outlined,
              title: s.medicineInfo,
              badge: '💊',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MedicineInfoScreen(),
                ),
              ),
            ),

            _menuItem(
              context,
              icon: Icons.assessment_outlined,
              title: s.reports,
              onTap: () => _showReports(context),
            ),

            const Divider(),
            const SizedBox(height: 8),

            // ── Section: Tools ───────────────────────────────
            _sectionHeader('Tools', textColor),

            _menuItem(
              context,
              icon: Icons.cloud_upload_outlined,
              title: s.bulkImport,
              onTap: () => _showBulkImport(context),
            ),

            _menuItem(
              context,
              icon: Icons.tune_outlined,
              title: s.customFields,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomFieldsScreen(),
                ),
              ),
            ),

            _menuItem(
              context,
              icon: Icons.local_offer_outlined,
              title: s.manageTags,
              onTap: () => _manageTags(context),
            ),

            _menuItem(
              context,
              icon: Icons.sync_outlined,
              title: s.syncInventory,
              onTap: () => _syncInventory(context),
            ),

            const Divider(),
            const SizedBox(height: 8),

            // ── Section: IoT ─────────────────────────────────
            _sectionHeader('IoT & Hardware', textColor),

            _menuItem(
              context,
              icon: Icons.bluetooth,
              title: 'Smart Cabinet Control',
              badge: '🔵 BLE',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SmartCabinetControlScreen(),
                ),
              ),
            ),

            _menuItem(
              context,
              icon: Icons.people_outline,
              title: 'Shared Cabinets',
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
            const SizedBox(height: 8),

            // ── Section: Support ─────────────────────────────
            _sectionHeader(s.helpSupport, textColor),

            _menuItem(
              context,
              icon: Icons.help_outline,
              title: s.helpSupport,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen(),
                ),
              ),
            ),

            const Divider(),
            const SizedBox(height: 8),

            // ── Section: Settings ────────────────────────────
            _sectionHeader(s.settings, textColor),

            _menuItem(
              context,
              icon: Icons.language,
              title: s.language,
              subtitle: '${languageProvider.getCurrentLanguageFlag()} ${languageProvider.getCurrentLanguageName()}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectorScreen(),
                ),
              ),
            ),

            // Dark mode toggle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: textColor.withValues(alpha: 0.7),
                ),
                title: Text(
                  themeProvider.isDarkMode ? s.lightMode : s.darkMode,
                  style: TextStyle(color: textColor),
                ),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (_) => themeProvider.toggleTheme(),
                  activeColor: const Color(0xFF4ECDC4),
                ),
                onTap: () => themeProvider.toggleTheme(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Logout ────────────────────────────────────────
            if (authProvider.isLoggedIn)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    s.logout,
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onTap: () => _signOut(context),
                ),
              ),

            const SizedBox(height: 24),

            // ── Footer ────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    'Smart Cabinet Finder',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '💡 Powered by ',
                        style: TextStyle(
                          fontSize: 11,
                          color: subColor,
                        ),
                      ),
                      Text(
                        'Gemini AI',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF4ECDC4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: textColor.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    VoidCallback? onTap,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.4);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: textColor.withValues(alpha: 0.7),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
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
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: subColor,
                  ),
                ],
              )
            : Icon(
                Icons.chevron_right,
                size: 18,
                color: subColor,
              ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
      ),
    );
  }
}