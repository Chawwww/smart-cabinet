// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _interestsController = TextEditingController();
  
  DateTime? _dateOfBirth;
  bool _isPublic = false;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _avatarUrl;
  File? _selectedImage;
  
  final List<String> _interestSuggestions = [
    'Technology', 'Cooking', 'Reading', 'Travel', 'Music',
    'Art', 'Sports', 'Photography', 'Gaming', 'Fitness',
    'Programming', 'Design', 'Writing', 'Gardening', 'Dancing',
    'Movies', 'Hiking', 'Cycling', 'Swimming', 'Yoga',
  ];

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        _loadUserData(user);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  void _loadUserData(UserModel user) {
    _nameController.text = user.name;
    _bioController.text = user.bio ?? '';
    _locationController.text = user.location ?? '';
    _phoneController.text = user.phoneNumber ?? '';
    _websiteController.text = user.website ?? '';
    _interestsController.text = user.interests.join(', ');
    _dateOfBirth = user.dateOfBirth;
    _isPublic = user.isPublic;
    _avatarUrl = user.avatar;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 13),
      helpText: 'Select Date of Birth',
    );
    
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) throw Exception('User not found');
      
      final authService = AuthService();
      
      // Upload image if selected
      String? avatarUrl = _avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await authService.uploadProfileImage(_selectedImage!, user.id!);
      }
      
      // Parse interests
      final interests = _interestsController.text
          .split(',')
          .map((i) => i.trim())
          .where((i) => i.isNotEmpty)
          .toList();
      
      // Update profile using authProvider
      await authProvider.updateFullProfile(
        name: _nameController.text.trim(),
        avatar: avatarUrl,
        dateOfBirth: _dateOfBirth,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        interests: interests.isEmpty ? null : interests,
        isPublic: _isPublic,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      );
      
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
          _selectedImage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;

    if (user == null) {
      return _buildNotLoggedIn(textColor, subColor);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () {
                _loadUserData(user);
                setState(() => _isEditing = true);
              },
              child: const Text(
                'Edit',
                style: TextStyle(color: Color(0xFF4ECDC4), fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Avatar Section ──────────────────────────────
              _buildAvatarSection(user, textColor, isDark, cardColor),
              
              const SizedBox(height: 24),
              
              // ── Profile Card ────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        enabled: _isEditing,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Name is required';
                          }
                          if (v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Bio - ✅ FIXED: Changed to Icons.description
                      _buildTextField(
                        controller: _bioController,
                        label: 'Bio',
                        icon: Icons.description,
                        enabled: _isEditing,
                        maxLines: 3,
                        hint: 'Tell us about yourself...',
                      ),
                      const SizedBox(height: 16),
                      
                      // Location
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        icon: Icons.location_on_outlined,
                        enabled: _isEditing,
                        hint: 'City, Country',
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        hint: '+60 12 345 6789',
                      ),
                      const SizedBox(height: 16),
                      
                      // Website
                      _buildTextField(
                        controller: _websiteController,
                        label: 'Website',
                        icon: Icons.link_outlined,
                        enabled: _isEditing,
                        keyboardType: TextInputType.url,
                        hint: 'https://yourwebsite.com',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ── Date of Birth ──────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date of Birth',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _isEditing ? _pickDateOfBirth : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: _isEditing ? const Color(0xFF4ECDC4) : subColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _dateOfBirth != null
                                      ? _dateFormat.format(_dateOfBirth!)
                                      : 'Not set',
                                  style: TextStyle(
                                    color: _dateOfBirth != null ? textColor : subColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (_dateOfBirth != null && _isEditing)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _dateOfBirth = null),
                                ),
                              if (_isEditing)
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: subColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_dateOfBirth != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Age: ${user.age} years old',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF4ECDC4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ── Interests ──────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interests',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isEditing) ...[
                        // Interest suggestions
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _interestSuggestions.map((interest) {
                              final currentInterests = _interestsController.text
                                  .split(',')
                                  .map((i) => i.trim())
                                  .toList();
                              final isSelected = currentInterests.contains(interest);
                              return ActionChip(
                                label: Text(interest),
                                onPressed: () {
                                  final current = _interestsController.text;
                                  if (isSelected) {
                                    final updated = current
                                        .split(',')
                                        .map((i) => i.trim())
                                        .where((i) => i != interest)
                                        .join(', ');
                                    _interestsController.text = updated;
                                  } else {
                                    if (current.isEmpty) {
                                      _interestsController.text = interest;
                                    } else {
                                      _interestsController.text = '$current, $interest';
                                    }
                                  }
                                  setState(() {});
                                },
                                backgroundColor: isSelected
                                    ? const Color(0xFF4ECDC4)
                                    : Colors.transparent,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : subColor,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF4ECDC4)
                                      : Colors.grey.shade400,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        _buildTextField(
                          controller: _interestsController,
                          label: 'Interests',
                          icon: Icons.favorite_outline,
                          enabled: _isEditing,
                          hint: 'E.g. Cooking, Travel, Technology',
                          isTextArea: true,
                        ),
                      ] else ...[
                        if (user.interests.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: user.interests.map((interest) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  interest,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Text(
                            'No interests added yet',
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ── Privacy Settings ───────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.public : Icons.lock_outline,
                        color: _isPublic ? const Color(0xFF4ECDC4) : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPublic ? 'Public Profile' : 'Private Profile',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              _isPublic
                                  ? 'Anyone can view your profile'
                                  : 'Only you can view your profile',
                              style: TextStyle(
                                color: subColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: _isEditing ? (v) => setState(() => _isPublic = v) : null,
                        activeColor: const Color(0xFF4ECDC4),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // ── Save / Cancel Buttons ──────────────────────
              if (_isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                                final user = context.read<AuthProvider>().currentUser;
                                if (user != null) {
                                  _loadUserData(user);
                                  setState(() {
                                    _isEditing = false;
                                    _selectedImage = null;
                                  });
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 24),
              
              // ── Sign Out ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Sign Out'),
                              content: const Text(
                                'Are you sure you want to sign out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
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
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar Section ─────────────────────────────────────
  Widget _buildAvatarSection(
    UserModel user,
    Color textColor,
    bool isDark,
    Color cardColor,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: _selectedImage != null
                ? Image.file(
                    _selectedImage!,
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                  )
                : _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? Image.network(
                        _avatarUrl!,
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultAvatar(user, textColor),
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: const Color(0xFF4ECDC4),
                              ),
                            ),
                          );
                        },
                      )
                    : _buildDefaultAvatar(user, textColor),
          ),
        ),
        // Upload button overlay
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  width: 3,
                ),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 22,
                ),
                onSelected: (value) {
                  if (value == 'gallery') {
                    _pickImage();
                  } else if (value == 'camera') {
                    _takePhoto();
                  } else if (value == 'remove') {
                    setState(() {
                      _selectedImage = null;
                      _avatarUrl = null;
                    });
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'gallery',
                    child: Row(
                      children: [
                        Icon(Icons.photo_library, color: Color(0xFF4ECDC4)),
                        SizedBox(width: 8),
                        Text('Choose from Gallery'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'camera',
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt, color: Color(0xFF4ECDC4)),
                        SizedBox(width: 8),
                        Text('Take Photo'),
                      ],
                    ),
                  ),
                  if (_avatarUrl != null || _selectedImage != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Photo', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Privacy badge
        Positioned(
          bottom: -20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPublic ? Icons.public : Icons.lock,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _isPublic ? 'Public' : 'Private',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(UserModel user, Color textColor) {
    return Container(
      width: 130,
      height: 130,
      color: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
      child: Center(
        child: Text(
          user.initials,
          style: TextStyle(
            color: const Color(0xFF4ECDC4),
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Text Field Builder ─────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isTextArea = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
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
        fillColor: enabled 
            ? (isDark ? const Color(0xFF2D2D2D) : Colors.white)
            : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50),
      ),
    );
  }

  // ── Not Logged In ──────────────────────────────────────
  Widget _buildNotLoggedIn(Color textColor, Color subColor) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 80,
              color: subColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Not logged in',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to view your profile',
              style: TextStyle(fontSize: 14, color: subColor),
            ),
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
      ),
    );
  }
}