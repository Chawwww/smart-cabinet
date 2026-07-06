// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for splash screen to show
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    
    // ✅ Set logout callback to clear data
    authProvider.setOnLogout(() {
      context.read<ItemProvider>().clearData();
      context.read<CategoryProvider>().clearData();
      context.read<CabinetProvider>().clearData();
      debugPrint('🧹 All data cleared on logout');
    });

    await authProvider.checkAuthStatus();

    if (!mounted) return;

    // ✅ If NOT logged in, clear all data and go to login
    if (!authProvider.isLoggedIn) {
      context.read<ItemProvider>().clearData();
      context.read<CategoryProvider>().clearData();
      context.read<CabinetProvider>().clearData();
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // ✅ If logged in, load data and go home
    context.read<ItemProvider>().loadItems();
    context.read<CategoryProvider>().loadCategories();
    context.read<CabinetProvider>()
      ..loadCabinets()
      ..loadBoxes();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.cabin, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Cabinet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Item Finder',
              style: TextStyle(fontSize: 18, color: subColor),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
            ),
          ],
        ),
      ),
    );
  }
}