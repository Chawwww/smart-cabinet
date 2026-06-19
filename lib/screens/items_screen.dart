import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/item_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
import 'item_detail_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().loadItems();
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    // FIX: theme-aware chip colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final chipBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    if (itemProvider.isLoading) return const LoadingWidget();

    final items = itemProvider.getFilteredItems(
      category: _selectedCategory,
      status: _selectedStatus,
    );

    return Column(
      children: [
        // Category chips
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _chip('All', _selectedCategory == 'All', chipBg, chipBorder,
                  () => setState(() => _selectedCategory = 'All')),
              ...categoryProvider.categories.map((cat) => _chip(
                    cat.name,
                    _selectedCategory == cat.id,
                    chipBg,
                    chipBorder,
                    () => setState(() => _selectedCategory = cat.id!),
                  )),
            ],
          ),
        ),
        // Status chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip('All', _selectedStatus == 'All', chipBg, chipBorder,
                  () => setState(() => _selectedStatus = 'All')),
              _chip('Inside', _selectedStatus == 'inside', chipBg, chipBorder,
                  () => setState(() => _selectedStatus = 'inside')),
              _chip('Taken', _selectedStatus == 'taken', chipBg, chipBorder,
                  () => setState(() => _selectedStatus = 'taken')),
              _chip('Expired', _selectedStatus == 'expired', chipBg, chipBorder,
                  () => setState(() => _selectedStatus = 'expired')),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'It\'s empty here',
                  subtitle: 'Add your first item by tapping the + button',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ItemCard(
                      item: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(item: item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, Color bg, Color border,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: bg,
        selectedColor: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
        checkmarkColor: const Color(0xFF4ECDC4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: selected ? const Color(0xFF4ECDC4) : border),
        ),
      ),
    );
  }
}