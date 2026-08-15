// lib/screens/menu_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';
import '../services/firestore_service.dart';
import '../models/item_model.dart';
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
import 'manage_cabinets_screen.dart'; // ✅ ADDED
import 'smart_cabinet_control_screen.dart';
import 'tag_management_screen.dart';
import 'notification_settings_screen.dart';

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

    showDialog(
      context: context,
      builder: (_) => _InventoryReportDialog(items: ip.items),
    );
  }

  // ── Tags ──────────────────────────────────────────────
  void _manageTags(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TagManagementScreen(),
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Profile card with Avatar ─────────────────────
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
                    // ✅ FIXED: Avatar with profile image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ClipOval(
                        child: (user?.avatar != null &&
                                user!.avatar!.isNotEmpty)
                            ? Image.network(
                                user.avatar!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : (authProvider.isLoggedIn ? 'U' : 'G'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                loadingBuilder: (_, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ??
                                (authProvider.isLoggedIn
                                    ? s.name
                                    : s.guestUser),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            user?.email ??
                                (authProvider.isLoggedIn
                                    ? s.loggedIn
                                    : s.guestUser),
                            style: TextStyle(
                              fontSize: 14,
                              color: subColor,
                            ),
                          ),
                          if (authProvider.isLoggedIn && user?.avatar != null)
                            Text(
                              '✓ ${s.googleAccount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF4ECDC4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (authProvider.isLoggedIn &&
                              user?.emailVerified == true)
                            Text(
                              '✓ ${s.verified}',
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

            // ✅ ADDED: Manage Cabinets
            _menuItem(
              context,
              icon: Icons.cabin_outlined,
              title: s.manageCabinets,
              subtitle:
                  '${cabinetProvider.ownedCabinets.length} owned • ${cabinetProvider.sharedCabinets.length} shared',
              badge: cabinetProvider.ownedCabinets.isNotEmpty
                  ? '${cabinetProvider.ownedCabinets.length}'
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageCabinetsScreen(),
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

            const Divider(),
            const SizedBox(height: 8),

            // ── Section: AI & Features ──────────────────────
            _sectionHeader(s.aiAndFeatures, textColor),

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
            _sectionHeader(s.tools, textColor),

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
            _sectionHeader(s.iotAndHardware, textColor),

            _menuItem(
              context,
              icon: Icons.bluetooth,
              title: s.smartCabinetControl,
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
              title: s.sharedCabinets,
              subtitle:
                  '${cabinetProvider.sharedCabinets.length} cabinets shared with you',
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
              subtitle:
                  '${languageProvider.getCurrentLanguageFlag()} ${languageProvider.getCurrentLanguageName()}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectorScreen(),
                ),
              ),
            ),

            _menuItem(
              context,
              icon: Icons.notifications_outlined,
              title: s.notificationSettings,
              subtitle: s.languageSaved,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
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
                  activeThumbColor: const Color(0xFF4ECDC4),
                  activeTrackColor: const Color(0xFF4ECDC4).withValues(alpha: 0.35),
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
                    s.smartCabinetFinder,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.6),
                    ),
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

class _InventoryReportDialog extends StatelessWidget {
  final List<ItemModel> items;
  const _InventoryReportDialog({required this.items});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.assessment, color: Color(0xFF4ECDC4)),
        const SizedBox(width: 8),
        Text(s.reports),
      ]),
      content: SizedBox(
        width: 420,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService().getItemHistory(),
          builder: (context, snapshot) {
            final history = snapshot.data ?? const [];
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                _quantityChart(history),
                const SizedBox(height: 20),
                _categoryChart(),
                const SizedBox(height: 12),
                Text(
                  history.isEmpty
                      ? 'New quantity changes will appear here after you add, remove, or edit stock.'
                      : 'Based on ${history.length} recorded stock changes.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF636E72)),
                ),
              ]),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.close))
      ],
    );
  }

  Widget _quantityChart(List<Map<String, dynamic>> history) {
    final now = DateTime.now();
    final days = List.generate(
        7,
        (i) => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i)));
    final changes = <String, int>{};
    for (final entry in history) {
      final raw = entry['timestamp'];
      final date = raw is Timestamp ? raw.toDate() : null;
      if (date == null) continue;
      final key = '${date.year}-${date.month}-${date.day}';
      changes[key] =
          (changes[key] ?? 0) + ((entry['quantity'] as num?)?.toInt() ?? 0);
    }
    final current = items.fold<int>(0, (total, item) => total + item.quantity);
    final lastWeekDelta = days.fold<int>(
        0,
        (total, day) =>
            total + (changes['${day.year}-${day.month}-${day.day}'] ?? 0));
    var running = current - lastWeekDelta;
    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      running += changes['${day.year}-${day.month}-${day.day}'] ?? 0;
      spots.add(FlSpot(i.toDouble(), running.toDouble()));
    }
    return SizedBox(
      height: 180,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Quantity over time (7 days)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Expanded(
            child: LineChart(LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF4ECDC4),
                barWidth: 3,
                dotData: const FlDotData(show: false))
          ],
        ))),
      ]),
    );
  }

  Widget _categoryChart() {
    final quantities = <String, int>{};
    for (final item in items) {
      final category = item.categoryId.isNotEmpty ? item.categoryId : 'Other';
      quantities[category] = (quantities[category] ?? 0) + item.quantity;
    }
    final entries =
        quantities.entries.where((entry) => entry.value > 0).take(6).toList();
    const colors = [
      Color(0xFF4ECDC4),
      Color(0xFFFFA94D),
      Color(0xFF45B7D1),
      Color(0xFFFF6B6B),
      Color(0xFF96CEB4),
      Color(0xFFDDA0DD)
    ];
    return SizedBox(
      height: 210,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Stock distribution by category',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No stock data yet'))
                : PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                            color: colors[i % colors.length],
                            value: entries[i].value.toDouble(),
                            title: '${entries[i].value}',
                            radius: 58,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))
                    ],
                  ))),
      ]),
    );
  }
}
