import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // Theme-aware colors — dark mode works automatically
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () {
                if (_isEditing) {
                  _saveProfile(authProvider);
                } else {
                  _nameController.text = user.name;
                  setState(() => _isEditing = true);
                }
              },
              child: Text(
                _isEditing ? 'Save' : 'Edit',
                style: const TextStyle(color: Color(0xFF4ECDC4)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: user == null
            // ── Not logged in ─────────────────────────────
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Icon(Icons.person_off_outlined,
                        size: 80, color: subColor.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Not logged in',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    const SizedBox(height: 8),
                    Text('Please sign in to view your profile',
                        style: TextStyle(fontSize: 14, color: subColor)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                        ),
                        child: const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              )
            // ── Logged in ─────────────────────────────────
            : Column(
                children: [
                  // Avatar
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ECDC4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(user.email,
                      style: TextStyle(fontSize: 14, color: subColor)),
                  const SizedBox(height: 24),

                  // Info card
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name row — editable
                          _isEditing
                              ? TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Display Name',
                                    prefixIcon:
                                        Icon(Icons.person_outline),
                                  ),
                                )
                              : _infoRow('Name', user.name, textColor, subColor),

                          const Divider(height: 24),
                          _infoRow('Email', user.email, textColor, subColor),
                          const Divider(height: 24),
                          _infoRow(
                            'Member Since',
                            '${user.createdAt.day.toString().padLeft(2, '0')}/'
                                '${user.createdAt.month.toString().padLeft(2, '0')}/'
                                '${user.createdAt.year}',
                            textColor,
                            subColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign out
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Sign Out',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                                'Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await authProvider.logout();
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _infoRow(
      String label, String value, Color textColor, Color subColor) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style:
                  TextStyle(fontWeight: FontWeight.w500, color: subColor)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Future<void> _saveProfile(AuthProvider authProvider) async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      await authProvider.updateProfile(name: newName);
    }
    setState(() => _isEditing = false);
  }
}