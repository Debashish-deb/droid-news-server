import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '/l10n/app_localizations.dart';
import 'auth_service.dart';
import '../../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _profile;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _imagePath;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _departmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await AuthService().getProfile();
      setState(() {
        _profile = data;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _roleController.text = data['role'] ?? '';
        _departmentController.text = data['department'] ?? '';
        _imagePath = data['image'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile')),
        );
      }
    }
  }

  Future<void> _toggleEdit() async {
    if (_isEditing) {
      if (_formKey.currentState!.validate()) {
        setState(() => _isSaving = true);
        try {
          await AuthService().updateProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            role: _roleController.text.trim(),
            department: _departmentController.text.trim(),
            imagePath: _imagePath ?? '',
          );
          await _loadProfile();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save profile')),
          );
        }
      }
    }
    setState(() {
      _isEditing = !_isEditing;
      _isSaving = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Enter email';
    if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final mode = context.watch<ThemeProvider>().appThemeMode;
    final isDark = brightness == Brightness.dark;

    final gradientColors = AppGradients.getGradientColors(mode);
    final startColor = gradientColors[0];
    final endColor = gradientColors[1];

    final inputTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          loc.profile,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const SizedBox(), // removed back button
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    startColor.withOpacity(0.85),
                    endColor.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          if (isDark) Container(color: Colors.black.withOpacity(0.6)),
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  _buildProfileHeader(isDark),
                  const SizedBox(height: 32),
                  _isEditing
                      ? _buildEditForm(inputTextStyle)
                      : _buildProfileDetails(isDark),
                  const SizedBox(height: 24),
                  _buildEditButton(isDark, loc),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: context.read<ThemeProvider>().glassDecoration(
                    borderRadius: BorderRadius.circular(16)),
                child: FloatingActionButton.extended(
                  heroTag: 'home',
                  onPressed: () => context.go('/home'),
                  icon: Icon(Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.black),
                  label: Text(loc.home,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: context.read<ThemeProvider>().glassDecoration(
                    borderRadius: BorderRadius.circular(16)),
                child: FloatingActionButton.extended(
                  heroTag: 'logout',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    context.go('/login');
                  },
                  icon: Icon(Icons.logout,
                      color: isDark ? Colors.white : Colors.black),
                  label: Text(loc.logout,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: _getProfileImage(),
                  child: _imagePath == null
                      ? Icon(Icons.person,
                          size: 48,
                          color: isDark ? Colors.white70 : Colors.black54)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _isEditing
                  ? TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(_nameController.text,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetails(bool isDark) {
    return Column(
      children: [
        _buildDetailRow('Email', _emailController.text, isDark),
        _buildDetailRow('Phone', _phoneController.text, isDark),
        _buildDetailRow('Role', _roleController.text, isDark),
        _buildDetailRow('Department', _departmentController.text, isDark),
      ],
    );
  }

  Widget _buildEditForm(TextStyle textStyle) {
    return Column(
      children: [
        _buildEditableField('Email', _emailController, validateEmail, textStyle),
        _buildEditableField('Phone', _phoneController, null, textStyle),
        _buildEditableField('Role', _roleController, null, textStyle),
        _buildEditableField('Department', _departmentController, null, textStyle),
      ],
    );
  }

  Widget _buildEditButton(bool isDark, AppLocalizations loc) {
    return ElevatedButton.icon(
      icon: _isSaving
          ? const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
          : Icon(_isEditing ? Icons.save : Icons.edit,
              color: isDark ? Colors.white : Colors.black),
      label: Text(
        _isEditing ? loc.save : loc.editProfile,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black),
      ),
      onPressed: _isSaving ? null : _toggleEdit,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: isDark ? Colors.white54 : Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller,
      String? Function(String?)? validator, TextStyle textStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        style: textStyle,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: textStyle.copyWith(fontWeight: FontWeight.normal),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: textStyle.color!.withOpacity(0.5)),
          ),
        ),
        validator: validator,
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_imagePath != null) {
      final file = File(_imagePath!);
      if (file.existsSync()) return FileImage(file);
    }
    final photoURL = FirebaseAuth.instance.currentUser?.photoURL;
    if (photoURL != null && photoURL.isNotEmpty) {
      return NetworkImage(photoURL);
    }
    return null;
  }
}
