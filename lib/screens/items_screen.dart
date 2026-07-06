// lib/screens/items_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/item_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
import 'item_detail_screen.dart';
import 'add_edit_item_screen.dart';
import 'share_cabinet_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});
  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  String _selectedCategoryId = 'All';
  String _selectedStatus     = 'All';
  String? _selectedCabinetId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().loadItems();
      context.read<CategoryProvider>().loadCategories();
      context.read<CabinetProvider>()
        ..loadCabinets()
        ..loadBoxes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider     = context.watch<ItemProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final cabinetProvider  = context.watch<CabinetProvider>();
    final authProvider     = context.watch<AuthProvider>();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    if (itemProvider.isLoading) return const LoadingWidget();

    final items = itemProvider.getFilteredItems(
      category: _selectedCategoryId,
      status:   _selectedStatus,
    );

    // Filter by cabinet if selected
    final filteredItems = _selectedCabinetId != null
        ? items.where((item) => item.cabinetId == _selectedCabinetId).toList()
        : items;

    return Column(
      children: [
        // ── Top bar: total count + Add button ────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Text(
                '${itemProvider.totalItems} items',
                style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddEditItemScreen()),
                ).then((_) => itemProvider.loadItems()),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item',
                    style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),

        // ── Category chips ────────────────────────────
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip(context, 'All', _selectedCategoryId == 'All',
                  isDark, () => setState(() {
                        _selectedCategoryId = 'All';
                      })),
              ...categoryProvider.categories.map((cat) => _chip(
                    context,
                    cat.name,
                    _selectedCategoryId == cat.id,
                    isDark,
                    () => setState(
                        () => _selectedCategoryId = cat.id ?? 'All'),
                    emoji: cat.icon,
                  )),
            ],
          ),
        ),

        // ── Status chips ──────────────────────────────
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            children: [
              _chip(context, 'All', _selectedStatus == 'All', isDark,
                  () => setState(() => _selectedStatus = 'All')),
              _chip(context, 'Inside', _selectedStatus == 'inside',
                  isDark,
                  () => setState(() => _selectedStatus = 'inside')),
              _chip(context, 'Taken', _selectedStatus == 'taken', isDark,
                  () => setState(() => _selectedStatus = 'taken')),
              _chip(context, 'Low Stock', _selectedStatus == 'low_stock',
                  isDark,
                  () =>
                      setState(() => _selectedStatus = 'low_stock')),
              _chip(context, 'Expired', _selectedStatus == 'expired',
                  isDark,
                  () => setState(() => _selectedStatus = 'expired')),
            ],
          ),
        ),

        // ── Cabinet filter with Share button ──────────
        if (cabinetProvider.accessibleCabinets.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _chip(context, 'All Cabinets', _selectedCabinetId == null,
                    isDark, () => setState(() => _selectedCabinetId = null)),
                ...cabinetProvider.accessibleCabinets.map((cabinet) {
                  final isOwner = cabinet.userId == authProvider.userId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _chip(
                          context,
                          '${cabinet.icon ?? '🗄️'} ${cabinet.name}',
                          _selectedCabinetId == cabinet.id,
                          isDark,
                          () => setState(() => _selectedCabinetId = cabinet.id),
                        ),
                        // ✅ Share button next to cabinet chip (only for owner)
                        if (isOwner)
                          IconButton(
                            icon: const Icon(Icons.share_outlined, 
                                size: 14, color: Color(0xFF4ECDC4)),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShareCabinetScreen(
                                  cabinetId: cabinet.id!,
                                  cabinetName: cabinet.name,
                                ),
                              ),
                            ),
                            tooltip: 'Share Cabinet',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

        // ── Grid ──────────────────────────────────────
        Expanded(
          child: filteredItems.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nothing here yet',
                  subtitle: 'Tap "Add Item" above to get started',
                  action: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddEditItemScreen()),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4)),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ItemCard(
                      item: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(item: item),
                        ),
                      ).then((_) => itemProvider.loadItems()),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool selected,
    bool isDark,
    VoidCallback onTap, {
    String? emoji,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF4ECDC4)
                : (isDark
                    ? const Color(0xFF2D2D2D)
                    : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4ECDC4)
                  : (isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: selected
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}