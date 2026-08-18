import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import '../widgets/category_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
import '../utils/responsive_layout.dart';
import 'add_edit_category_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
      context.read<ItemProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final itemProvider = context.watch<ItemProvider>();
    final s = S.of(context);

    if (categoryProvider.isLoading) return const LoadingWidget();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.categories),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4ECDC4)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditCategoryScreen()),
            ),
          ),
        ],
      ),
      body: categoryProvider.categories.isEmpty
          ? EmptyState(
              icon: Icons.category_outlined,
              title: s.noCategories,
              subtitle: s.createFirstCategory,
              action: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddEditCategoryScreen()),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4)),
                child: Text(s.addCategory),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.gridCols(context),
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categoryProvider.categories.length,
              itemBuilder: (context, index) {
                final cat = categoryProvider.categories[index];
                final count = itemProvider.items
                    .where((i) => i.categoryId == cat.id)
                    .length;
                return CategoryCard(
                  category: cat,
                  itemCount: count,
                  onTap: () =>
                      Navigator.pushNamed(context, '/items', arguments: cat.id),
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddEditCategoryScreen(category: cat)),
                  ),
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(s.deleteCategory),
                        content: Text(
                            'Delete "${cat.name}"? Items in this category will also be deleted.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(s.cancel)),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: Text(s.delete)),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await categoryProvider.deleteCategory(cat.id!);
                    }
                  },
                );
              },
            ),
    );
  }
}
