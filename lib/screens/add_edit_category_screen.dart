import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import '../providers/auth_provider.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final CategoryModel? category;
  const AddEditCategoryScreen({super.key, this.category});

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedIcon;
  String? _selectedColor;
  bool _isLoading = false;

  final List<String> _icons = [
    '📦','💊','🍕','🥤','🔧','📄','📱','💻',
    '📺','🎮','📚','👕','👟','🧢','👜','🎒',
    '🔑','🖊️','📌','📎','🔌','💡','🔦','🧰',
    '🪑','🛋️','🛏️','🚪','🪟','🧹','🧺','🪣',
    '🎯','🏷️','📋','📊','🏥','🧴','🧪','🍼',
  ];

  final List<String> _colors = [
    '#FF6B6B','#FFA94D','#FDCB6E','#00B894',
    '#4ECDC4','#45B7D1','#6C5CE7','#A29BFE',
    '#FD79A8','#E17055','#00CEC9','#0984E3',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedIcon  = widget.category!.icon;
      _selectedColor = widget.category!.color;
    } else {
      _selectedIcon  = _icons.first;
      _selectedColor = _colors[4]; // teal default
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthProvider>().currentUser?.id ?? '';
      final cat = CategoryModel(
        id: widget.category?.id,
        name: _nameController.text.trim(),
        icon: _selectedIcon ?? '📦',
        color: _selectedColor ?? '#4ECDC4',
        itemCount: widget.category?.itemCount ?? 0,
        createdAt: widget.category?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        userId: userId,
      );
      if (widget.category == null) {
        await context.read<CategoryProvider>().addCategory(cat);
      } else {
        await context.read<CategoryProvider>().updateCategory(cat);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final gridBg    = isDark ? const Color(0xFF2D2D2D) : Colors.white;

    Color previewColor;
    try {
      previewColor = _selectedColor != null
          ? Color(int.parse(_selectedColor!.replaceFirst('#', '0xFF')))
          : const Color(0xFF4ECDC4);
    } catch (_) {
      previewColor = const Color(0xFF4ECDC4);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4ECDC4)),
                  ))
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save',
                      style: TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: previewColor.withValues(alpha: isDark ? 0.22 : 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(_selectedIcon ?? '📦',
                            style: const TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _nameController.text.isEmpty ? 'Category Name' : _nameController.text,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Name field
              TextFormField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 20),

              // Icon picker
              Text('Choose Icon',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              Container(
                height: 130,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gridBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _icons.length,
                  itemBuilder: (_, i) {
                    final icon = _icons[i];
                    final sel = _selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF4ECDC4).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: sel
                              ? Border.all(color: const Color(0xFF4ECDC4), width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(icon, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Color picker
              Text('Choose Color',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((c) {
                  Color col;
                  try { col = Color(int.parse(c.replaceFirst('#', '0xFF'))); }
                  catch (_) { col = Colors.grey; }
                  final sel = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: textColor, width: 3)
                            : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: sel
                            ? [BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 6)]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(
                    widget.category == null ? 'Add Category' : 'Update Category',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}