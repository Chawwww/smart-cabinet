import 'package:flutter/material.dart';

import '../widgets/bottom_navigation.dart';
import '../widgets/custom_app_bar.dart';

import 'workflows_screen.dart';
import 'items_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'menu_screen.dart';
import 'add_edit_item_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;

  final List<Widget> _screens = const [
    WorkflowsScreen(),
    ItemsScreen(),
    SearchScreen(),
    NotificationsScreen(),
    MenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: Remove hardcoded color — uses Theme.of(context).scaffoldBackgroundColor automatically
      appBar: const CustomAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF4ECDC4),
              elevation: 4,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}