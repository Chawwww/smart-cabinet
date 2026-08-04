// lib/screens/manage_cabinets_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_model.dart'; // ✅ ADD THIS IMPORT
import '../providers/cabinet_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/cabinet_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
import 'add_edit_cabinet_screen.dart';
import 'cabinet_detail_screen.dart';

class ManageCabinetsScreen extends StatefulWidget {
  const ManageCabinetsScreen({super.key});

  @override
  State<ManageCabinetsScreen> createState() => _ManageCabinetsScreenState();
}

class _ManageCabinetsScreenState extends State<ManageCabinetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CabinetProvider>().loadCabinets();
      context.read<CabinetProvider>().loadBoxes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cabinetProvider = context.watch<CabinetProvider>();
    final authProvider = context.watch<AuthProvider>();
    final textColor = Theme.of(context).colorScheme.onSurface;

    if (cabinetProvider.isLoading) {
      return const Scaffold(
        body: LoadingWidget(),
      );
    }

    final ownedCabinets = cabinetProvider.ownedCabinets;
    final sharedCabinets = cabinetProvider.sharedCabinets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cabinets'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4ECDC4),
          unselectedLabelColor: textColor.withValues(alpha: 0.5),
          indicatorColor: const Color(0xFF4ECDC4),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cabin, size: 16),
                  const SizedBox(width: 6),
                  Text('My Cabinets (${ownedCabinets.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 16),
                  const SizedBox(width: 6),
                  Text('Shared (${sharedCabinets.length})'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4ECDC4)),
            onPressed: () {
              cabinetProvider.reloadCabinets();
              cabinetProvider.reloadBoxes();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing cabinets...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4ECDC4)),
            onPressed: () => _addCabinet(context),
            tooltip: 'Add Cabinet',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Owned Cabinets Tab ──
          ownedCabinets.isEmpty
              ? _buildEmptyState(
                  icon: Icons.cabin_outlined,
                  title: 'No Cabinets Yet',
                  subtitle: 'Create your first cabinet to start organizing',
                  action: () => _addCabinet(context),
                )
              : _buildCabinetGrid(ownedCabinets, authProvider),
          
          // ── Shared Cabinets Tab ──
          sharedCabinets.isEmpty
              ? _buildEmptyState(
                  icon: Icons.people_outline,
                  title: 'No Shared Cabinets',
                  subtitle: 'When someone shares a cabinet with you, it will appear here',
                  action: null,
                )
              : _buildCabinetGrid(sharedCabinets, authProvider),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? action,
  }) {
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: subColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: subColor),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Cabinet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCabinetGrid(
    List<CabinetModel> cabinets,
    AuthProvider authProvider,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cabinets.length,
      itemBuilder: (context, index) {
        final cabinet = cabinets[index];
        
        return CabinetCard(
          cabinet: cabinet,
          itemCount: cabinet.itemCount,
          boxCount: cabinet.boxCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CabinetDetailScreen(
                cabinetId: cabinet.id!,
              ),
            ),
          ),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditCabinetScreen(cabinet: cabinet),
            ),
          ).then((_) => context.read<CabinetProvider>().reloadCabinets()),
        );
      },
    );
  }

  void _addCabinet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditCabinetScreen(),
      ),
    ).then((_) {
      context.read<CabinetProvider>().reloadCabinets();
      context.read<CabinetProvider>().reloadBoxes();
    });
  }
}