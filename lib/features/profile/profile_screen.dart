import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/theme_providers.dart'
    show glassColorProvider, glassShadowsProvider;
import '../../core/theme.dart';
import '../../presentation/providers/theme_providers.dart'
    show glassColorProvider, glassShadowsProvider;
import '../../presentation/providers/theme_providers.dart' as theme;
import '../../core/services/favorites_providers.dart';
import '../../core/services/offline_service.dart';
import '/l10n/app_localizations.dart';
import '../../presentation/providers/language_providers.dart';
import '../../core/utils/number_localization.dart';
import 'auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../core/theme/tokens.dart'; // BUILD_FIXES: Design tokens
import '../../core/security/input_sanitizer.dart'; // BUILD_FIXES: Security

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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

  int _favoritesCount = 0;
  int _downloadsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStatistics();
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
      debugPrint('❌ Profile load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final favorites = ref.read(favoritesProvider);
      final downloads = await OfflineService.getDownloadedCount();
      setState(() {
        _favoritesCount = favorites.articles.length;
        _downloadsCount = downloads;
      });
    } catch (e) {
      debugPrint('❌ Statistics load error: $e');
    }
  }

  Future<void> _toggleEdit() async {
    if (_isEditing) {
      if (_formKey.currentState!.validate()) {
        setState(() => _isSaving = true);
        try {
          await AuthService().updateProfile(
            name: InputSanitizer.sanitizeText(_nameController.text),
            email: InputSanitizer.sanitizeEmail(_emailController.text) ?? _emailController.text,
            phone: InputSanitizer.sanitizeText(_phoneController.text),
            role: InputSanitizer.sanitizeText(_roleController.text),
            department: InputSanitizer.sanitizeText(_departmentController.text),
            imagePath: _imagePath ?? '',
          );
          await _loadProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save profile')),
            );
          }
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

    final flutterTheme = Theme.of(context);
    final brightness = flutterTheme.brightness;
    final themeState = ref.watch(theme.themeProvider);
    final mode = themeState.mode;
    final isDark = brightness == Brightness.dark;

    final gradientColors = AppGradients.getGradientColors(mode);
    final startColor = gradientColors[0];
    final endColor = gradientColors[1];

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
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: _toggleEdit,
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
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

          // Content
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  _buildProfileCard(isDark, loc),
                  const SizedBox(height: 16),
                  _buildStatisticsCards(isDark),
                  const SizedBox(height: 16),
                  _buildInformationSection(isDark, loc),
                  const SizedBox(height: 16),
                  _buildActionButtons(isDark, loc),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildBottomButtons(isDark, loc),
    );
  }

  Widget _buildProfileCard(bool isDark, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          // Profile Image
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child:
                      _imagePath != null && _imagePath!.startsWith('http')
                          ? CachedNetworkImage(
                            imageUrl: _imagePath!,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color:
                                      isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) =>
                                    _buildDefaultAvatar(isDark),
                          )
                          : _buildDefaultAvatar(isDark),
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          _isEditing
              ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TextFormField(
                  controller: _nameController,
                  style: AppTypography.headline2.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: loc.enterName,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty == true ? loc.nameRequired : null,
                ),
              )
              : Text(
                _nameController.text.isEmpty
                    ? 'User Name'
                    : _nameController.text,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
          const SizedBox(height: 8),

          // Email
          Text(
            _emailController.text.isEmpty
                ? 'user@example.com'
                : _emailController.text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey[300],
      child: Icon(
        Icons.person,
        size: 50,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
    );
  }

  Widget _buildStatisticsCards(bool isDark) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final String languageCode = ref.watch(languageCodeProvider);
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            loc.favorites,
            _favoritesCount,
            Icons.favorite,
            Colors.red,
            isDark,
            languageCode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            loc.downloaded,
            _downloadsCount,
            Icons.download,
            Colors.green,
            isDark,
            languageCode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    int count,
    IconData icon,
    Color color,
    bool isDark,
    String languageCode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            localizeNumber('$count', languageCode),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationSection(bool isDark, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              loc.information,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const Divider(height: 1),
          _isEditing
              ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildEditField(
                      loc.emailLabel,
                      _emailController,
                      Icons.email,
                      validateEmail,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(
                      loc.phoneLabel,
                      _phoneController,
                      Icons.phone,
                      null,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(
                      loc.roleLabel,
                      _roleController,
                      Icons.work,
                      null,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(
                      loc.departmentLabel,
                      _departmentController,
                      Icons.business,
                      null,
                      isDark,
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  _buildInfoTile(
                    loc.emailLabel,
                    _emailController.text,
                    Icons.email,
                    isDark,
                  ),
                  _buildInfoTile(
                    loc.phoneLabel,
                    _phoneController.text,
                    Icons.phone,
                    isDark,
                  ),
                  _buildInfoTile(
                    loc.roleLabel,
                    _roleController.text,
                    Icons.work,
                    isDark,
                  ),
                  _buildInfoTile(
                    loc.departmentLabel,
                    _departmentController.text,
                    Icons.business,
                    isDark,
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? Colors.white70 : Colors.black54,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.black38,
        ),
      ),
      subtitle: Text(
        value.isEmpty ? loc.notSet : value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon,
    String? Function(String?)? validator,
    bool isDark,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor:
            isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildActionButtons(bool isDark, AppLocalizations loc) {
    if (!_isEditing) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close),
            label: Text(loc.cancel),
            onPressed: () {
              setState(() {
                _isEditing = false;
                _loadProfile(); // Reset fields
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.save),
            label: Text(loc.save),
            onPressed: _isSaving ? null : _toggleEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(bool isDark, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ref.watch(glassColorProvider),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: ref.watch(glassShadowsProvider),
              ),
              child: FloatingActionButton.extended(
                heroTag: 'home',
                onPressed: () => context.go('/home'),
                icon: Icon(
                  Icons.home_outlined,
                  color: isDark ? Colors.white : Colors.black,
                ),
                label: Text(
                  loc.home,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ref.watch(glassColorProvider),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: ref.watch(glassShadowsProvider),
              ),
              child: FloatingActionButton.extended(
                heroTag: 'logout',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: Text(loc.logout),
                          content: Text(loc.logoutConfirmation),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(loc.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                loc.logout,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );
                  if (confirmed == true) {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) context.go('/login');
                  }
                },
                icon: Icon(
                  Icons.logout,
                  color: isDark ? Colors.white : Colors.black,
                ),
                label: Text(
                  loc.logout,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
