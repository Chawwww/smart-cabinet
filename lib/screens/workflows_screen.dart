import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';
import 'add_edit_item_screen.dart';
import 'item_detail_screen.dart';

class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({super.key});
  @override
  State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends State<WorkflowsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().loadItems();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Tab bar ─────────────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4ECDC4),
            unselectedLabelColor: textColor.withValues(alpha: 0.5),
            indicatorColor: const Color(0xFF4ECDC4),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Stock Count'),
              Tab(icon: Icon(Icons.list_alt,     size: 18), text: 'Pick List'),
              Tab(icon: Icon(Icons.shopping_cart, size: 18), text: 'Purchase'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _StockCountTab(),
              _PickListTab(),
              _PurchaseOrderTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// TAB 1 — STOCK COUNT
// Show all items; user can +/- quantity inline
// ════════════════════════════════════════════════
class _StockCountTab extends StatelessWidget {
  const _StockCountTab();

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final textColor    = Theme.of(context).colorScheme.onSurface;
    final subColor     = textColor.withValues(alpha: 0.55);

    if (itemProvider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)));
    }

    if (itemProvider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 80, color: subColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No items to count',
                style: TextStyle(fontSize: 18, color: textColor)),
            const SizedBox(height: 8),
            Text('Add items first from the Items tab',
                style: TextStyle(fontSize: 13, color: subColor)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemProvider.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final item = itemProvider.items[i];
        return _StockCountCard(item: item, itemProvider: itemProvider);
      },
    );
  }
}

class _StockCountCard extends StatefulWidget {
  final ItemModel item;
  final ItemProvider itemProvider;
  const _StockCountCard({required this.item, required this.itemProvider});

  @override
  State<_StockCountCard> createState() => _StockCountCardState();
}

class _StockCountCardState extends State<_StockCountCard> {
  late int _qty;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qty = widget.item.quantity;
  }

  Future<void> _update(int delta) async {
    final newQty = (_qty + delta).clamp(0, 99999);
    setState(() { _qty = newQty; _saving = true; });
    await widget.itemProvider.updateItem(
        widget.item.copyWith(quantity: newQty, updatedAt: DateTime.now()));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    Color qtyColor = const Color(0xFF00B894);
    if (_qty == 0)               qtyColor = Colors.red;
    else if (widget.item.isLowStock) qtyColor = Colors.orange;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Icon
            Text(widget.item.icon ?? '📦',
                style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor)),
                  Text(widget.item.unit,
                      style: TextStyle(fontSize: 12, color: subColor)),
                  if (widget.item.isLowStock)
                    Text('Low stock!',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            // Qty controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  onPressed: _saving ? null : () => _update(-1),
                  iconSize: 28,
                ),
                SizedBox(
                  width: 42,
                  child: _saving
                      ? const Center(
                          child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4ECDC4))))
                      : Text('$_qty',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: qtyColor)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF4ECDC4),
                  onPressed: _saving ? null : () => _update(1),
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// TAB 2 — PICK LIST
// User taps items to "pick" them; marks status=taken
// ════════════════════════════════════════════════
class _PickListTab extends StatefulWidget {
  const _PickListTab();
  @override
  State<_PickListTab> createState() => _PickListTabState();
}

class _PickListTabState extends State<_PickListTab> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final textColor    = Theme.of(context).colorScheme.onSurface;
    final subColor     = textColor.withValues(alpha: 0.55);

    final available = itemProvider.items
        .where((i) => i.status == 'inside')
        .toList();

    return Column(
      children: [
        // Header bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('${_picked.length} picked',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const Spacer(),
              if (_picked.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _confirmPickup(context, itemProvider),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Confirm Pickup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    minimumSize: const Size(0, 36),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: available.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt_outlined,
                          size: 60, color: subColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No items inside cabinet',
                          style: TextStyle(color: textColor)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = available[i];
                    final isPicked = _picked.contains(item.id);
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: CheckboxListTile(
                        value: isPicked,
                        onChanged: (v) => setState(() {
                          if (v == true) _picked.add(item.id!);
                          else _picked.remove(item.id);
                        }),
                        activeColor: const Color(0xFF4ECDC4),
                        secondary: Text(item.icon ?? '📦',
                            style: const TextStyle(fontSize: 26)),
                        title: Text(item.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                                decoration: isPicked
                                    ? TextDecoration.lineThrough
                                    : null)),
                        subtitle: Text(
                            '${item.quantity} ${item.unit}',
                            style: TextStyle(fontSize: 12, color: subColor)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmPickup(
      BuildContext context, ItemProvider itemProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Pickup'),
        content: Text(
            'Mark ${_picked.length} item(s) as taken from cabinet?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4)),
              child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    for (final id in _picked) {
      final item = itemProvider.items.firstWhere((i) => i.id == id);
      await itemProvider.updateItem(
          item.copyWith(status: 'taken', updatedAt: DateTime.now()));
    }

    setState(() => _picked.clear());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Items marked as taken'),
            backgroundColor: Color(0xFF00B894)),
      );
    }
  }
}

// ════════════════════════════════════════════════
// TAB 3 — PURCHASE ORDERS
// Low stock / out-of-stock items to reorder
// ════════════════════════════════════════════════
class _PurchaseOrderTab extends StatefulWidget {
  const _PurchaseOrderTab();
  @override
  State<_PurchaseOrderTab> createState() => _PurchaseOrderTabState();
}

class _PurchaseOrderTabState extends State<_PurchaseOrderTab> {
  final Set<String> _toOrder = {};

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final textColor    = Theme.of(context).colorScheme.onSurface;
    final subColor     = textColor.withValues(alpha: 0.55);

    final needsReorder = [
      ...itemProvider.outOfStockItems,
      ...itemProvider.lowStockItems
          .where((i) => !itemProvider.outOfStockItems.contains(i)),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('${needsReorder.length} items need restock',
                  style: TextStyle(fontSize: 14, color: textColor,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_toOrder.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _showOrderSummary(context, needsReorder),
                  icon: const Icon(Icons.shopping_cart, size: 16),
                  label: Text('Order ${_toOrder.length}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    minimumSize: const Size(0, 36),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: needsReorder.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 60,
                          color: const Color(0xFF00B894).withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('All items are well stocked!',
                          style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                              fontWeight: FontWeight.w600)),
                      Text('No purchase orders needed',
                          style: TextStyle(color: subColor)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: needsReorder.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = needsReorder[i];
                    final isOut  = item.quantity == 0;
                    final toOrd  = _toOrder.contains(item.id);
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: CheckboxListTile(
                        value: toOrd,
                        onChanged: (v) => setState(() {
                          if (v == true) _toOrder.add(item.id!);
                          else _toOrder.remove(item.id);
                        }),
                        activeColor: const Color(0xFF6C5CE7),
                        secondary: Stack(
                          children: [
                            Text(item.icon ?? '📦',
                                style: const TextStyle(fontSize: 26)),
                            Positioned(
                              right: 0, top: 0,
                              child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: isOut ? Colors.red : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(item.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                        subtitle: Text(
                          isOut
                              ? 'Out of stock'
                              : 'Low: ${item.quantity} ${item.unit} left',
                          style: TextStyle(
                              fontSize: 12,
                              color: isOut ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showOrderSummary(BuildContext context, List<ItemModel> needsReorder) {
    final selectedItems = needsReorder
        .where((i) => _toOrder.contains(i.id))
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final textColor = Theme.of(context).colorScheme.onSurface;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Purchase Order Summary',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 12),
              ...selectedItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(item.icon ?? '📦'),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(item.name,
                                style: TextStyle(color: textColor))),
                        Text(
                          'Need: ${(item.lowStockThreshold - item.quantity).clamp(1, 9999)} ${item.unit}',
                          style: const TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              '📋 Purchase order created! (Export to PDF coming soon)'),
                          backgroundColor: Color(0xFF6C5CE7)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7)),
                  child: const Text('Create Order'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}