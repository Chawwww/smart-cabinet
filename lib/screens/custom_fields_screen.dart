import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../models/item_model.dart';

// ════════════════════════════════════════════════
// Custom Fields Screen
// Lets user define + manage global custom field
// templates, then apply values per item.
// ════════════════════════════════════════════════

class CustomFieldsScreen extends StatefulWidget {
  const CustomFieldsScreen({super.key});
  @override
  State<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends State<CustomFieldsScreen> {
  // Predefined field templates (stored locally for this session;
  // in production save to Firestore /users/{uid}/custom_field_templates)
  final List<CustomFieldTemplate> _templates = [
    CustomFieldTemplate(name: 'Serial Number',   type: FieldType.text,   icon: Icons.qr_code),
    CustomFieldTemplate(name: 'Purchase Price',  type: FieldType.number, icon: Icons.attach_money),
    CustomFieldTemplate(name: 'Purchase Date',   type: FieldType.date,   icon: Icons.receipt_long),
    CustomFieldTemplate(name: 'Warranty Until',  type: FieldType.date,   icon: Icons.verified_user),
    CustomFieldTemplate(name: 'Supplier',        type: FieldType.text,   icon: Icons.store),
    CustomFieldTemplate(name: 'Storage Temp °C', type: FieldType.number, icon: Icons.thermostat),
    CustomFieldTemplate(name: 'Weight (kg)',     type: FieldType.number, icon: Icons.scale),
    CustomFieldTemplate(name: 'Color',           type: FieldType.text,   icon: Icons.palette),
    CustomFieldTemplate(name: 'Size',            type: FieldType.text,   icon: Icons.straighten),
    CustomFieldTemplate(name: 'Reorder From',    type: FieldType.text,   icon: Icons.shopping_cart),
  ];

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Fields'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4ECDC4)),
            tooltip: 'Add custom field',
            onPressed: () => _showAddFieldDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF4ECDC4), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Custom fields let you add extra attributes to any item — '
                    'like serial numbers, warranty dates, or supplier names. '
                    'Tap any field to edit it when adding or editing an item.',
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Available Fields',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 12),

          // Field list
          ..._templates.asMap().entries.map((entry) {
            final i    = entry.key;
            final tmpl = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tmpl.icon,
                      color: const Color(0xFF4ECDC4), size: 20),
                ),
                title: Text(tmpl.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: textColor)),
                subtitle: Text(_fieldTypeLabel(tmpl.type),
                    style: TextStyle(fontSize: 12, color: subColor)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF4ECDC4)),
                      onPressed: () =>
                          _showEditFieldDialog(context, i, tmpl),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () => _confirmDelete(context, i),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Apply to items section
          Text('Apply to Items',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 8),
          Text(
            'Select an item below to fill in its custom field values.',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 12),
          _ItemCustomFieldsList(templates: _templates),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4ECDC4),
        icon: const Icon(Icons.add),
        label: const Text('New Field'),
        onPressed: () => _showAddFieldDialog(context),
      ),
    );
  }

  String _fieldTypeLabel(FieldType t) {
    switch (t) {
      case FieldType.text:   return 'Text field';
      case FieldType.number: return 'Number field';
      case FieldType.date:   return 'Date field';
      case FieldType.bool:   return 'Yes/No toggle';
    }
  }

  void _showAddFieldDialog(BuildContext context) {
    _showFieldDialog(context, null, null);
  }

  void _showEditFieldDialog(
      BuildContext context, int index, CustomFieldTemplate tmpl) {
    _showFieldDialog(context, index, tmpl);
  }

  void _showFieldDialog(
      BuildContext context, int? editIndex, CustomFieldTemplate? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    FieldType selectedType = existing?.type ?? FieldType.text;
    IconData selectedIcon  = existing?.icon ?? Icons.label_outline;

    final icons = [
      Icons.label_outline, Icons.qr_code, Icons.attach_money,
      Icons.receipt_long, Icons.verified_user, Icons.store,
      Icons.thermostat, Icons.scale, Icons.palette,
      Icons.straighten, Icons.shopping_cart, Icons.info_outline,
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        final textColor = Theme.of(ctx).colorScheme.onSurface;
        return AlertDialog(
          title: Text(editIndex == null ? 'Add Custom Field' : 'Edit Field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Field Name',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                Text('Field Type',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: FieldType.values.map((t) {
                    final sel = selectedType == t;
                    return ChoiceChip(
                      label: Text(_fieldTypeLabel(t)),
                      selected: sel,
                      onSelected: (_) =>
                          setLocal(() => selectedType = t),
                      selectedColor:
                          const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('Icon',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((ic) {
                    final sel = selectedIcon == ic;
                    return GestureDetector(
                      onTap: () => setLocal(() => selectedIcon = ic),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF4ECDC4)
                                  .withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF4ECDC4)
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Icon(ic,
                            size: 20,
                            color: sel
                                ? const Color(0xFF4ECDC4)
                                : Colors.grey),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  final tmpl = CustomFieldTemplate(
                    name: name,
                    type: selectedType,
                    icon: selectedIcon,
                  );
                  if (editIndex == null) {
                    _templates.add(tmpl);
                  } else {
                    _templates[editIndex] = tmpl;
                  }
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4)),
              child: Text(editIndex == null ? 'Add' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text(
            'Delete "${_templates[index].name}"? '
            'This will not affect existing item data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) setState(() => _templates.removeAt(index));
  }
}

// ── Per-item custom field values editor ──────────────
class _ItemCustomFieldsList extends StatelessWidget {
  final List<CustomFieldTemplate> templates;
  const _ItemCustomFieldsList({required this.templates});

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final textColor    = Theme.of(context).colorScheme.onSurface;
    final subColor     = textColor.withValues(alpha: 0.55);

    if (itemProvider.items.isEmpty) {
      return Text('No items yet.',
          style: TextStyle(color: subColor, fontSize: 13));
    }

    return Column(
      children: itemProvider.items.map((item) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Text(item.icon ?? '📦',
                style: const TextStyle(fontSize: 24)),
            title: Text(item.name,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: textColor)),
            subtitle: Text(
              '${item.customFields.length} custom fields filled',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            trailing: const Icon(Icons.chevron_right,
                color: Color(0xFF4ECDC4)),
            onTap: () => _showItemFieldEditor(context, item, itemProvider),
          ),
        );
      }).toList(),
    );
  }

  void _showItemFieldEditor(
      BuildContext context, ItemModel item, ItemProvider provider) {
    final controllers = <String, TextEditingController>{};
    final values      = Map<String, dynamic>.from(item.customFields);

    for (final tmpl in templates) {
      controllers[tmpl.name] =
          TextEditingController(text: values[tmpl.name]?.toString() ?? '');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final textColor = Theme.of(context).colorScheme.onSurface;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Custom Fields — ${item.name}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 16),
              ...templates.map((tmpl) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildFieldInput(tmpl, controllers[tmpl.name]!),
                  )),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final updated = Map<String, dynamic>.from(values);
                  for (final tmpl in templates) {
                    final v = controllers[tmpl.name]!.text.trim();
                    if (v.isNotEmpty) updated[tmpl.name] = v;
                  }
                  await provider.updateItem(
                      item.copyWith(customFields: updated,
                          updatedAt: DateTime.now()));
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Save Fields',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFieldInput(
      CustomFieldTemplate tmpl, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: tmpl.type == FieldType.number
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: tmpl.name,
        prefixIcon: Icon(tmpl.icon, size: 18),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// DATA CLASSES
// ════════════════════════════════════════════════

enum FieldType { text, number, date, bool }

class CustomFieldTemplate {
  final String name;
  final FieldType type;
  final IconData icon;
  const CustomFieldTemplate(
      {required this.name, required this.type, required this.icon});
}