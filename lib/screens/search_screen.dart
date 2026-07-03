import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../widgets/item_card.dart';
import '../widgets/empty_state.dart';
import 'item_detail_screen.dart';

// SUPERVISOR REQ 4: Keyword/partial search
// Typing "ca" shows items containing "ca": calcium, cabinet key, etc.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<ItemProvider>().loadItems();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.5);
    final searchBg  = isDark ? const Color(0xFF2D2D2D) : Colors.white;

    // SUPERVISOR REQ 4: Partial keyword search
    // searchItems() uses .contains() — so "ca" matches "calcium",
    // "cabinet key", "car wax" etc.
    final results = itemProvider.searchItems(_query);

    return Column(
      children: [
        // ── Search bar ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                      alpha: isDark ? 0.3 : 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.search,
                      color: Color(0xFF636E72), size: 20),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: false,
                    onChanged: (v) =>
                        setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search items… e.g. "ca" or "para"',
                      hintStyle: TextStyle(
                          color: subColor, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 13),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _ctrl.clear();
                      _query = '';
                    }),
                  ),
              ],
            ),
          ),
        ),

        // ── Result count hint ──────────────────────
        if (_query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  results.isEmpty
                      ? 'No results for "$_query"'
                      : '${results.length} result${results.length == 1 ? '' : 's'} for "$_query"',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),

        // ── Results ────────────────────────────────
        Expanded(
          child: _query.isEmpty
              ? _buildEmptyState(subColor)
              : results.isEmpty
                  ? _buildNoResults(subColor)
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: results.length,
                      itemBuilder: (ctx, i) => ItemCard(
                        item: results[i],
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) =>
                                ItemDetailScreen(item: results[i]),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color subColor) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 72,
                color: subColor.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('Search your items',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: subColor)),
            const SizedBox(height: 8),
            Text('Type any partial word — e.g. "ca", "para", "tab"',
                style: TextStyle(fontSize: 13, color: subColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Searches name, brand, description, tags, notes',
                style: TextStyle(
                    fontSize: 11,
                    color: subColor.withValues(alpha: 0.7)),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _buildNoResults(Color subColor) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 72,
                color: subColor.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No items match "$_query"',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: subColor)),
            const SizedBox(height: 8),
            Text('Try a shorter keyword or check spelling',
                style: TextStyle(fontSize: 13, color: subColor),
                textAlign: TextAlign.center),
          ],
        ),
      );
}