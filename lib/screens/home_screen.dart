// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/l10n.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/responsive_navigation.dart';
import '../utils/responsive_layout.dart';

import 'workflows_screen.dart';
import 'items_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'menu_screen.dart';
import 'ai_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;

  final List<Widget> _screens = const [
    WorkflowsScreen(),
    ItemsScreen(),
    SearchScreen(),
    NotificationsScreen(),
    MenuScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // ✅ Refresh user data when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        authProvider.refreshUserData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.currentUser;
    final isDark = themeProvider.isDarkMode;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final s = S.of(context);
    final isMobile = Responsive.isMobile(context);
    const navigationItems = [
      NavigationItem(
          icon: Icons.assessment_outlined,
          selectedIcon: Icons.assessment,
          label: 'Workflows'),
      NavigationItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Items'),
      NavigationItem(
          icon: Icons.search_outlined,
          selectedIcon: Icons.search,
          label: 'Search'),
      NavigationItem(
          icon: Icons.notifications_outlined,
          selectedIcon: Icons.notifications,
          label: 'Alerts'),
      NavigationItem(
          icon: Icons.menu_outlined, selectedIcon: Icons.menu, label: 'Menu'),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cabin, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(s.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ),
          ],
        ),
        actions: [
          // AI Chat shortcut
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF4ECDC4)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AIChatScreen())),
            tooltip: s.aiAssistant,
          ),
          // Dark mode toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: textColor.withValues(alpha: 0.6),
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          // Avatar
          SizedBox(
            width: 48,
            height: 48,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _selectedIndex = 4),
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ECDC4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user != null && user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : 'G',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: isMobile
          ? IndexedStack(index: _selectedIndex, children: _screens)
          : Row(
              children: [
                ResponsiveNavigation(
                  selectedIndex: _selectedIndex,
                  items: navigationItems,
                  onTap: (i) => setState(() => _selectedIndex = i),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child:
                      IndexedStack(index: _selectedIndex, children: _screens),
                ),
              ],
            ),
      bottomNavigationBar: isMobile
          ? BottomNavigation(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
            )
          : null,
    );
  }
}
