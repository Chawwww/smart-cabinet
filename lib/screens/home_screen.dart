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

  final List<Widget> _screens = [
    const WorkflowsScreen(),
    const ItemsScreen(),
    const SearchScreen(),
    const NotificationsScreen(),
    const MenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FFFF),

      // App Bar
      appBar: const CustomAppBar(),

      // Body
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),

      // Floating Add Button (Items page only)
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF4ECDC4),
              elevation: 4,
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditItemScreen(),
                  ),
                );
              },
            )
          : null,

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }
}