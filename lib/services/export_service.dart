// lib/services/export_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';
import '../models/category_model.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  // ── Export to CSV ──
  Future<File> exportToCSV(List<ItemModel> items) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln([
      'Name',
      'Description',
      'Category',
      'Brand',
      'Quantity',
      'Unit',
      'Status',
      'Expiry Date',
      'Production Date',
      'Tags',
      'Notes',
      'Created At',
      'Updated At',
    ].join(','));

    // Data rows
    for (final item in items) {
      final row = [
        _escapeCSV(item.name),
        _escapeCSV(item.description ?? ''),
        _escapeCSV(item.categoryId), // Should resolve to category name
        _escapeCSV(item.brand ?? ''),
        item.quantity.toString(),
        _escapeCSV(item.unit),
        _escapeCSV(item.status),
        item.expiryDate != null ? _dateFormat.format(item.expiryDate!) : '',
        item.productionDate != null ? _dateFormat.format(item.productionDate!) : '',
        _escapeCSV(item.tags.join('; ')),
        _escapeCSV(item.note ?? ''),
        _dateFormat.format(item.createdAt),
        _dateFormat.format(item.updatedAt),
      ];
      buffer.writeln(row.join(','));
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/inventory_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    return file;
  }

  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── Export to JSON ──
  Future<File> exportToJSON(List<ItemModel> items) async {
    final data = items.map((item) => {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'categoryId': item.categoryId,
      'cabinetId': item.cabinetId,
      'boxId': item.boxId,
      'brand': item.brand,
      'quantity': item.quantity,
      'initialQuantity': item.initialQuantity,
      'unit': item.unit,
      'status': item.status,
      'expiryDate': item.expiryDate?.toIso8601String(),
      'productionDate': item.productionDate?.toIso8601String(),
      'tags': item.tags,
      'note': item.note,
      'createdAt': item.createdAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
    }).toList();

    final json = jsonEncode(data);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/inventory_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);

    return file;
  }

  // ── Export and Share ──
  Future<void> shareExport(List<ItemModel> items, {String format = 'csv'}) async {
    try {
      File file;
      if (format.toLowerCase() == 'json') {
        file = await exportToJSON(items);
      } else {
        file = await exportToCSV(items);
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📦 Inventory Export from Smart Cabinet Finder',
      );
    } catch (e) {
      debugPrint('❌ Share export error: $e');
      rethrow;
    }
  }

  // ── Generate Stock Report ──
  String generateStockReport(List<ItemModel> items) {
    final total = items.length;
    final expired = items.where((i) => i.isExpired).length;
    final expiringSoon = items.where((i) => i.isExpiringSoon).length;
    final lowStock = items.where((i) => i.isLowStock).length;
    final outOfStock = items.where((i) => i.isOutOfStock).length;
    final inside = items.where((i) => i.status == 'inside').length;
    final taken = items.where((i) => i.status == 'taken').length;

    return '''
═══════════════════════════════════
📊 INVENTORY STOCK REPORT
═══════════════════════════════════
Generated: ${DateTime.now().toString()}
───────────────────────────────────
📦 Total Items:     $total
───────────────────────────────────
✅ Inside Cabinet:  $inside
📤 Taken:           $taken
───────────────────────────────────
⚠️ Expired:         $expired
⏰ Expiring Soon:   $expiringSoon
📉 Low Stock:       $lowStock
🚫 Out of Stock:    $outOfStock
───────────────────────────────────
📋 Items with expiry:  ${items.where((i) => i.hasExpiry).length}
🏷️ Total categories:  ${items.map((i) => i.categoryId).toSet().length}
───────────────────────────────────
💡 Tip: Items with "Low Stock" or
"Expiring Soon" need immediate attention.
═══════════════════════════════════
''';
  }
}