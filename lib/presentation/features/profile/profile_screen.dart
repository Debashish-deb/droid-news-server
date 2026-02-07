import 'dart:io' show File;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design_tokens.dart';
import '../../../core/app_icons.dart';
import '../../../core/theme.dart';
import '../../../core/utils/number_localization.dart';
import '../../../core/security/input_sanitizer.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/language_providers.dart';
import '../../../infrastructure/persistence/offline_service.dart' show OfflineService;
import '../../providers/theme_providers.dart' as theme show themeProvider;
import '../../widgets/app_drawer.dart';
import '../../providers/feature_providers.dart';
import '../../providers/premium_providers.dart';
import '../settings/widgets/settings_3d_widgets.dart';
import '../../widgets/glass_pill_button.dart';
import '../../widgets/glass_icon_button.dart';
import '../common/app_bar.dart';
import 'dart:ui';

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
      final data = await ref.read(authServiceProvider).getProfile();
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
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).failedToLoadProfile)));
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
          await ref.read(authServiceProvider).updateProfile(
            name: InputSanitizer.sanitizeText(_nameController.text),
            email: InputSanitizer.sanitizeEmail(_emailController.text) ?? _emailController.text,
            phone: InputSanitizer.sanitizeText(_phoneController.text),
            role: InputSanitizer.sanitizeText(_roleController.text),
            department: InputSanitizer.sanitizeText(_departmentController.text),
            imagePath: _imagePath ?? '',
          );
          await _loadProfile();
          if (mounted) {
            final loc = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.profileUpdated),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            final loc = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.failedToSaveProfile)),
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

  // Add the resolveImage method here
  static ImageProvider<Object>? resolveImage(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('http')) return NetworkImage(path);
    if (path.startsWith('assets/')) return AssetImage(path);
    final File file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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

    final gradientColors = AppGradients.getBackgroundGradient(mode);
    final startColor = gradientColors[0];
    final endColor = gradientColors[1];

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        title: AppBarTitle(loc.profile),
        leading: Builder(
          builder: (context) => Center(
            child: GlassIconButton(
              icon: Icons.menu_rounded,
              onPressed: () => Scaffold.of(context).openDrawer(),
              isDark: isDark,
            ),
          ),
        ),
        leadingWidth: 64,
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GlassIconButton(
                icon: Icons.edit_outlined,
                onPressed: _toggleEdit,
                isDark: isDark,
              ),
            ),
        ],
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

       
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  const SizedBox(height: 8),
                  _buildProfileCard(isDark, loc),
                  const SizedBox(height: 16),
                  _buildStatisticsCards(isDark),
                  const SizedBox(height: 16),
                  _buildInformationSection(isDark, loc),
                  const SizedBox(height: 16),
                  _buildActionButtons(isDark, loc),
                  const SizedBox(height: 120), // Increased padding to avoid FAB overlap
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
    final selectionColor = ref.watch(navIconColorProvider);
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return ClipRRect(
      borderRadius: AppRadius.xlBorder,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              
              // 3D Avatar Frame (Synced with AppDrawer)
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                    // 3D Hexagonal Glass Box Avatar
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Glow
                        ClipPath(
                          clipper: _HexagonClipper(),
                          child: Container(
                            width: 100,
                            height: 115,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  selectionColor.withOpacity(0.6),
                                  selectionColor.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Inner Glass & Image
                        ClipPath(
                          clipper: _HexagonClipper(),
                          child: Container(
                            width: 96,
                            height: 111,
                            padding: const EdgeInsets.all(2),
                            color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.4),
                            child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _imagePath != null && (_imagePath!.startsWith('http') || _imagePath!.startsWith('assets/') || _imagePath!.startsWith('/'))
                                      ? Image(
                                          image: resolveImage(_imagePath!)!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(AppIcons.person, size: 40, color: isDark ? Colors.white54 : Colors.black54),
                                        )
                                      : Icon(
                                          AppIcons.person,
                                          size: 40,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                  
                                  // 3D "Oval" Lens Effect
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        radius: 0.8,
                                        colors: [
                                          Colors.white.withOpacity(0.1),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.2),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ],
                            ),
                          ),
                        ),
                        // Top Gloss
                        ClipPath(
                          clipper: _HexagonClipper(),
                          child: Container(
                            width: 96,
                            height: 111,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.3],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                            color: selectionColor,
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
              const SizedBox(height: 12),
    
              _isEditing
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        fontFamily: AppTypography.fontFamily,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: loc.enterName,
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        border: InputBorder.none,
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
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      fontFamily: AppTypography.fontFamily,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
              
              if (isPremium) ...[
                const SizedBox(height: 8),
                // Pill-Glass Premium Tag (Synced)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selectionColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selectionColor.withOpacity(0.4),
                      width: 1.2
                    ),
                  ),
                  child: Text(
                    'PREMIUM MEMBER',
                    style: TextStyle(
                      color: selectionColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontFamily: AppTypography.fontFamily,
                    ),
                  ),
                ),
              ],
    
              const SizedBox(height: 8),
              
              Text(
                _emailController.text.isEmpty
                    ? 'user@example.com'
                    : _emailController.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey[300],
      child: Icon(
        Icons.person,
        size: 35,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
    );
  }

  Widget _buildStatisticsCards(bool isDark) {
    final AppLocalizations loc = AppLocalizations.of(context);
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
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                localizeNumber('$count', languageCode),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: '.SF Pro Display',
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationSection(bool isDark, AppLocalizations loc) {
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  loc.information.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontFamily: '.SF Pro Display',
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              _isEditing
                  ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildEditField(
                          loc.emailLabel,
                          _emailController,
                          Icons.email_outlined,
                          validateEmail,
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildEditField(
                          loc.phoneLabel,
                          _phoneController,
                          Icons.phone_outlined,
                          null,
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildEditField(
                          loc.roleLabel,
                          _roleController,
                          Icons.work_outline,
                          null,
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildEditField(
                          loc.departmentLabel,
                          _departmentController,
                          Icons.business_outlined,
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
                        Icons.email_outlined,
                        isDark,
                      ),
                      _buildInfoTile(
                        loc.phoneLabel,
                        _phoneController.text,
                        Icons.phone_outlined,
                        isDark,
                      ),
                      _buildInfoTile(
                        loc.roleLabel,
                        _roleController.text,
                        Icons.work_outline,
                        isDark,
                      ),
                      _buildInfoTile(
                        loc.departmentLabel,
                        _departmentController.text,
                        Icons.business_outlined,
                        isDark,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    final AppLocalizations loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Compact Padding
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // Compact Icon
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value.isEmpty ? loc.notSet : value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: '.SF Pro Display',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final borderColor = ref.watch(borderColorProvider);

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
          fontFamily: '.SF Pro Display',
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.45),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(
            icon, 
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, AppLocalizations loc) {
    if (!_isEditing) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: GlassPillButton(
            icon: Icons.close,
            label: loc.cancel,
            onPressed: () {
              setState(() {
                _isEditing = false;
                _loadProfile(); 
              });
            },
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassPillButton(
            icon: Icons.save,
            label: loc.save,
            onPressed: _isSaving ? null : _toggleEdit,
            isDark: isDark,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(bool isDark, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Settings3DButton(
              onTap: () => context.go('/home'),
              label: loc.home,
              icon: Icons.home_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Settings3DButton(
              onTap: () async {
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
                  await ref.read(authServiceProvider).logout();
                  if (mounted) context.go('/login');
                }
              },
              label: loc.logout,
              icon: Icons.logout_rounded,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double width = size.width;
    final double height = size.height;
    
    path.moveTo(width * 0.5, 0); // Top Center
    path.lineTo(width, height * 0.25); // Top Right
    path.lineTo(width, height * 0.75); // Bottom Right
    path.lineTo(width * 0.5, height); // Bottom Center
    path.lineTo(0, height * 0.75); // Bottom Left
    path.lineTo(0, height * 0.25); // Top Left
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}