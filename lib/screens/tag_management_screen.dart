// lib/screens/tag_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../models/item_model.dart';

class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({super.key});

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  String _searchQuery = '';
  List<String> _selectedTags = [];
  
  @override
  void initState() {
    super.initState();
    // Ensure items are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    
    // Get all unique tags with their count
    final tagMap = <String, int>{};
    for (final item in itemProvider.items) {
      for (final tag in item.tags) {
        tagMap[tag] = (tagMap[tag] ?? 0) + 1;
      }
    }
    
    final allTags = tagMap.keys.toList()..sort();
    final filteredTags = _searchQuery.isEmpty
        ? allTags
        : allTags.where((t) => 
            t.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Manage Tags'),
        elevation: 0,
        actions: [
          if (allTags.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: () => _confirmClearAllTags(context, itemProvider),
              tooltip: 'Clear all tags',
            ),
        ],
      ),
      body: itemProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4ECDC4),
              ),
            )
          : Column(
              children: [
                // ── Search Bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tags...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4ECDC4),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                
                // ── Stats ────────────────────────────────────
                if (allTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${allTags.length} total tags',
                          style: TextStyle(
                            color: subColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedTags.isNotEmpty)
                          Text(
                            '${_selectedTags.length} selected',
                            style: TextStyle(
                              color: const Color(0xFF4ECDC4),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // ── Tags Grid ──────────────────────────────
                Expanded(
                  child: allTags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tag_outlined,
                                size: 80,
                                color: subColor.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No tags found'
                                    : 'No tags matching "$_searchQuery"',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: subColor,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Add tags to your items to see them here',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : filteredTags.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 60,
                                    color: subColor.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No tags match "$_searchQuery"',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: subColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredTags.length,
                              itemBuilder: (context, index) {
                                final tag = filteredTags[index];
                                final count = tagMap[tag] ?? 0;
                                final isSelected = _selectedTags.contains(tag);
                                
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedTags.remove(tag);
                                      } else {
                                        _selectedTags.add(tag);
                                      }
                                    });
                                  },
                                  onLongPress: () => _showTagActions(context, tag, itemProvider),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF4ECDC4).withValues(alpha: 0.15)
                                          : (isDark ? const Color(0xFF2D2D2D) : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4ECDC4)
                                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        if (!isDark)
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.tag,
                                                color: isSelected
                                                    ? const Color(0xFF4ECDC4)
                                                    : subColor,
                                                size: 28,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                tag,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? const Color(0xFF4ECDC4)
                                                      : textColor,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$count item${count > 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: subColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF4ECDC4),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                
                // ── Bottom Actions ──────────────────────────
                if (_selectedTags.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedTags.length} selected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedTags.clear());
                          },
                          child: const Text('Clear'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _confirmDeleteTags(context, itemProvider),
                          icon: const Icon(Icons.delete, size: 16),
                          label: Text('Delete (${_selectedTags.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  // ── Tag Actions Bottom Sheet ─────────────────────────

  void _showTagActions(BuildContext context, String tag, ItemProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tag: $tag',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF4ECDC4)),
              title: const Text('Rename Tag'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, tag, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Color(0xFF4ECDC4)),
              title: const Text('Find Items with this Tag'),
              onTap: () {
                Navigator.pop(context);
                _navigateToItemsWithTag(context, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Tag from All Items'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTag(context, tag, provider);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Rename Tag Dialog ─────────────────────────────────

  void _showRenameDialog(BuildContext context, String oldTag, ItemProvider provider) {
    final controller = TextEditingController(text: oldTag);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Rename Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the new name for this tag. It will be updated on all items.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New tag name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              autofocus: true,
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTag = controller.text.trim();
              if (newTag.isEmpty || newTag == oldTag) {
                Navigator.pop(context);
                return;
              }
              
              Navigator.pop(context);
              
              // Update all items with this tag
              int updatedCount = 0;
              for (final item in provider.items) {
                if (item.tags.contains(oldTag)) {
                  final updatedTags = item.tags
                      .map((t) => t == oldTag ? newTag : t)
                      .toList();
                  await provider.updateItem(
                    item.copyWith(
                      tags: updatedTags,
                      updatedAt: DateTime.now(),
                    ),
                  );
                  updatedCount++;
                }
              }
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Renamed "$oldTag" to "$newTag" ($updatedCount items updated)'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  // ── Find Items with Tag ───────────────────────────────

  void _navigateToItemsWithTag(BuildContext context, String tag) {
    Navigator.pop(context);
    // Navigate to home first, then items with search
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => route.isFirst,
    );
    
    // Show a snackbar with the search suggestion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔍 Searching for items with tag: "$tag"'),
          backgroundColor: const Color(0xFF4ECDC4),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  // ── Confirm Delete Single Tag ─────────────────────────

  void _confirmDeleteTag(BuildContext context, String tag, ItemProvider provider) {
    final affectedItems = provider.items.where((i) => i.tags.contains(tag)).length;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove tag "$tag" from all items?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'This will affect $affectedItems item(s).',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Remove tag from all items
              int updatedCount = 0;
              for (final item in provider.items) {
                if (item.tags.contains(tag)) {
                  await provider.updateItem(
                    item.copyWith(
                      tags: item.tags.where((t) => t != tag).toList(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  updatedCount++;
                }
              }
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Removed tag "$tag" from $updatedCount item(s)'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                setState(() {});
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Confirm Delete Multiple Tags ──────────────────────

  void _confirmDeleteTags(BuildContext context, ItemProvider provider) {
    final count = _selectedTags.length;
    final tagsList = _selectedTags.join(", ");
    
    // Count affected items
    int affectedItems = 0;
    for (final item in provider.items) {
      if (item.tags.any((t) => _selectedTags.contains(t))) {
        affectedItems++;
      }
    }
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Tags'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove $_selectedTags.length selected tag(s) from all items?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Affected tags: $tagsList',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This will affect $affectedItems item(s).',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Remove selected tags from all items
              int updatedCount = 0;
              for (final item in provider.items) {
                final updatedTags = item.tags
                    .where((t) => !_selectedTags.contains(t))
                    .toList();
                if (updatedTags.length != item.tags.length) {
                  await provider.updateItem(
                    item.copyWith(
                      tags: updatedTags,
                      updatedAt: DateTime.now(),
                    ),
                  );
                  updatedCount++;
                }
              }
              
              setState(() => _selectedTags.clear());
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Removed $count tag(s) from $updatedCount item(s)'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Confirm Clear All Tags ────────────────────────────

  void _confirmClearAllTags(BuildContext context, ItemProvider provider) {
    final totalTags = provider.items.fold(0, (sum, item) => sum + item.tags.length);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Clear All Tags'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will remove ALL tags from ALL items.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Total tags to remove: $totalTags',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ This action cannot be undone!',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              int updatedCount = 0;
              for (final item in provider.items) {
                if (item.tags.isNotEmpty) {
                  await provider.updateItem(
                    item.copyWith(
                      tags: [],
                      updatedAt: DateTime.now(),
                    ),
                  );
                  updatedCount++;
                }
              }
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Cleared all tags from $updatedCount item(s)'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                setState(() {});
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}