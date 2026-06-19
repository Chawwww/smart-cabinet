import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import '../widgets/category_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
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
    final itemProvider     = context.watch<ItemProvider>();

    if (categoryProvider.isLoading) return const LoadingWidget();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4ECDC4)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddEditCategoryScreen()),
            ),
          ),
        ],
      ),
      body: categoryProvider.categories.isEmpty
          ? EmptyState(
              icon: Icons.category_outlined,
              title: 'No Categories',
              subtitle: 'Create your first category to organise your items',
              action: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddEditCategoryScreen()),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4)),
                child: const Text('Add Category'),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
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
                  onTap: () => Navigator.pushNamed(
                      context, '/items',
                      arguments: cat.id),
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddEditCategoryScreen(category: cat)),
                  ),
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Category'),
                        content: Text(
                            'Delete "${cat.name}"? Items in this category will also be deleted.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Delete')),
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