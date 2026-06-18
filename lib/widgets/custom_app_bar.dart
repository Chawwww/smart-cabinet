import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    // FIX 1: Use theme colors — dark mode now works
    final bg = Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).scaffoldBackgroundColor;
    final iconColor = Theme.of(context).colorScheme.onSurface;

    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      automaticallyImplyLeading: false, // FIX 2: Never show back arrow in main app bar
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.cabin, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Smart Cabinet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome, color: Color(0xFF4ECDC4)),
          onPressed: () => Navigator.pushNamed(context, '/ai-chat'),
        ),
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: iconColor.withValues(alpha: 0.7),
          ),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        if (authProvider.isLoggedIn && authProvider.currentUser != null)
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  authProvider.currentUser!.name.isNotEmpty
                      ? authProvider.currentUser!.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )
        else
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: const Text(
              'Login',
              style: TextStyle(
                color: Color(0xFF4ECDC4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}