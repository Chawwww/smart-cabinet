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
    
    if (itemProvider.isLoading) {
      return const LoadingWidget();
    }
    
    final items = itemProvider.getFilteredItems(
      category: _selectedCategory,
      status: _selectedStatus,
    );
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCategoryChip('All', _selectedCategory == 'All'),
              ...categoryProvider.categories.map((category) {
                return _buildCategoryChip(
                  category.name,
                  _selectedCategory == category.id,
                );
              }),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildStatusChip('All', _selectedStatus == 'All'),
              _buildStatusChip('Inside', _selectedStatus == 'inside'),
              _buildStatusChip('Taken', _selectedStatus == 'taken'),
              _buildStatusChip('Expired', _selectedStatus == 'expired'),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemDetailScreen(item: item),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = selected ? 'All' : label;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
        checkmarkColor: const Color(0xFF4ECDC4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? const Color(0xFF4ECDC4) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedStatus = selected ? 'All' : label.toLowerCase();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
        checkmarkColor: const Color(0xFF4ECDC4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? const Color(0xFF4ECDC4) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}