import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_manager.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _presets = [1, 3, 7, 14, 30];

  int _selectedDays = 7;
  final _customCtrl = TextEditingController();
  bool _useCustom = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final days = await NotificationManager().getExpiryAlertDays(userId);
    setState(() {
      if (_presets.contains(days)) {
        _selectedDays = days;
        _useCustom = false;
      } else {
        _useCustom = true;
        _customCtrl.text = days.toString();
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;

    final days = _useCustom
        ? int.tryParse(_customCtrl.text.trim())
        : _selectedDays;

    if (days == null || days < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of days')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await NotificationManager().setExpiryAlertDays(userId, days);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ You\'ll be alerted $days day(s) before expiry')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF4ECDC4), size: 18),
                  const SizedBox(width: 8),
                  Text('Expiry Reminder',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Choose how many days before an item expires you\'d '
                  'like to be alerted. You\'ll keep getting a daily '
                  'reminder for as long as the item stays expiring/expired.',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
                const SizedBox(height: 16),

                // Preset chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map((d) {
                    final sel = !_useCustom && _selectedDays == d;
                    return ChoiceChip(
                      label: Text('$d day${d == 1 ? '' : 's'}'),
                      selected: sel,
                      selectedColor: const Color(0xFF4ECDC4).withValues(alpha: 0.25),
                      onSelected: (_) => setState(() {
                        _useCustom = false;
                        _selectedDays = d;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Custom option ("or any")
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _useCustom,
                  selectedColor: const Color(0xFF4ECDC4).withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _useCustom = true),
                ),
                if (_useCustom) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Days before expiry',
                      hintText: 'e.g. 10',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),

                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF4ECDC4), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Door-open and low-stock alerts are sent '
                        'automatically — nothing to configure for those.',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}