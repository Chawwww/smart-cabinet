// lib/widgets/responsive_navigation.dart
import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';

class ResponsiveNavigation extends StatelessWidget {
  final int selectedIndex;
  final List<NavigationItem> items;
  final Function(int) onTap;

  const ResponsiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final layout = Responsive.layoutOf(context);

    if (layout == AppLayout.desktop) {
      return _buildDesktopNavigation(context);
    } else if (layout == AppLayout.tablet) {
      return _buildTabletNavigation(context);
    } else {
      return _buildMobileNavigation(context);
    }
  }

  Widget _buildMobileNavigation(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      height: 64,
      destinations: items.map((item) => NavigationDestination(
        icon: Icon(item.icon),
        selectedIcon: Icon(item.selectedIcon ?? item.icon),
        label: item.label,
      )).toList(),
    );
  }

  Widget _buildTabletNavigation(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      destinations: items.map((item) => NavigationRailDestination(
        icon: Icon(item.icon),
        selectedIcon: Icon(item.selectedIcon ?? item.icon),
        label: Text(item.label),
      )).toList(),
    );
  }

  Widget _buildDesktopNavigation(BuildContext context) {
    return Container(
      width: Responsive.sidebarWidth,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 24),
          // App Logo
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cabin, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Smart Cabinet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return ListTile(
                  leading: Icon(
                    isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
                    color: isSelected ? const Color(0xFF4ECDC4) : null,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF4ECDC4) : null,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                  onTap: () => onTap(index),
                );
              },
            ),
          ),
          const Divider(),
          // User info at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF4ECDC4),
                  child: const Text(
                    'U',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'User',
                    style: TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}