// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/bottom_navigation.dart';

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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cabin, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text('Smart Cabinet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
          ],
        ),
        actions: [
          // AI Chat shortcut
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF4ECDC4)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AIChatScreen())),
            tooltip: 'AI Assistant',
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
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 4),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4),
                borderRadius: BorderRadius.circular(15),
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
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}