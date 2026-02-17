import 'dart:io' show File;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_icons.dart' show AppIcons;
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../../../core/theme.dart';
import '../../../core/utils/number_localization.dart';
import '../../../core/security/input_sanitizer.dart';

import '../../providers/favorites_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/premium_providers.dart';

import '../../../infrastructure/persistence/offline_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/glass_pill_button.dart';
import '../../widgets/glass_icon_button.dart';
import '../settings/widgets/settings_3d_widgets.dart';
import '../common/app_bar.dart';

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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).failedToLoadProfile)),
      );
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
    } catch (_) {}
  }

  Future<void> _toggleEdit() async {
    if (_isEditing && _formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        await ref.read(authServiceProvider).updateProfile(
              name: InputSanitizer.sanitizeText(_nameController.text),
              email: InputSanitizer.sanitizeEmail(_emailController.text) ??
                  _emailController.text,
              phone: InputSanitizer.sanitizeText(_phoneController.text),
              role: InputSanitizer.sanitizeText(_roleController.text),
              department:
                  InputSanitizer.sanitizeText(_departmentController.text),
              imagePath: _imagePath ?? '',
            );
        await _loadProfile();
      } catch (_) {}
    }

    setState(() {
      _isEditing = !_isEditing;
      _isSaving = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imagePath = picked.path);
  }

  static ImageProvider<Object>? resolveImage(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('http')) return NetworkImage(path);
    if (path.startsWith('assets/')) return AssetImage(path);
    final file = File(path);
    return file.existsSync() ? FileImage(file) : null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mode = ref.watch(themeProvider).mode;
    final gradient = AppGradients.getBackgroundGradient(mode);

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
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
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
                    gradient[0].withOpacity(0.9),
                    gradient[1].withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildProfileCard(isDark, loc),
                  const SizedBox(height: 18),
                  _buildStatisticsCards(isDark),
                  const SizedBox(height: 18),
                  _buildInformationSection(isDark, loc),
                  const SizedBox(height: 24),
                  _buildActionButtons(isDark, loc),
                  const SizedBox(height: 120),
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

  // ───────────────── PROFILE CARD ─────────────────

  Widget _buildProfileCard(bool isDark, AppLocalizations loc) {
    final accent = ref.watch(navIconColorProvider);
    final glass = ref.watch(glassColorProvider);
    final border = ref.watch(borderColorProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return ClipRRect(
      borderRadius: AppRadius.xlBorder,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: glass,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(color: border.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.28 : 0.14),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 22),

              /// Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _HexAvatar(
                    imagePath: _imagePath,
                    accent: accent,
                    isDark: isDark,
                  ),
                  if (_isEditing)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              /// Name
              _isEditing
                  ? TextFormField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: const InputDecoration(border: InputBorder.none),
                    )
                  : Text(
                      _nameController.text.isEmpty
                          ? loc.userNamePlaceholder
                          : _nameController.text,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),

              const SizedBox(height: 6),

              /// Email (subtle)
              Text(
                _emailController.text.isEmpty
                    ? 'user@example.com'
                    : _emailController.text,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.45),
                ),
              ),

              if (isPremium.valueOrNull ?? false) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accent.withOpacity(0.25)),
                  ),
                  child: Text(
                    loc.premiumMemberBadge,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── STATS ─────────────────

  Widget _buildStatisticsCards(bool isDark) {
    final lang = ref.watch(languageCodeProvider);
    final loc = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: loc.favorites,
            value: _favoritesCount,
            icon: Icons.favorite,
            color: Colors.red,
            isDark: isDark,
            languageCode: lang,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            label: loc.downloaded,
            value: _downloadsCount,
            icon: Icons.download,
            color: Colors.green,
            isDark: isDark,
            languageCode: lang,
          ),
        ),
      ],
    );
  }

  // ───────────────── INFO SECTION ─────────────────

  Widget _buildInformationSection(bool isDark, AppLocalizations loc) {
    final glass = ref.watch(glassColorProvider);
    final border = ref.watch(borderColorProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: glass,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border.withOpacity(0.6)),
          ),
          child: Column(
            children: [
              _InfoTile(label: loc.emailLabel, value: _emailController.text),
              _InfoTile(label: loc.phoneLabel, value: _phoneController.text),
              _InfoTile(label: loc.roleLabel, value: _roleController.text),
              _InfoTile(
                  label: loc.departmentLabel,
                  value: _departmentController.text),
              const SizedBox(height: 8),
            ],
          ),
        ),
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
        const SizedBox(width: 14),
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
    return Row(
      children: [
        Expanded(
          child: Settings3DButton(
            label: loc.home,
            icon: Icons.home_outlined,
            onTap: () => context.go('/home'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Settings3DButton(
            label: loc.logout,
            icon: Icons.logout_rounded,
            isDestructive: true,
            onTap: () async {
              await ref.read(authServiceProvider).logout();
              if (mounted) context.go('/login');
            },
          ),
        ),
      ],
    );
  }
}

/// ───────────────── SUPPORT WIDGETS ─────────────────

class _HexAvatar extends StatelessWidget {
  final String? imagePath;
  final Color accent;
  final bool isDark;

  const _HexAvatar({
    required this.imagePath,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HexagonClipper(),
      child: Container(
        width: 96,
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withOpacity(0.6),
              accent.withOpacity(0.15),
            ],
          ),
        ),
        child: imagePath != null
            ? Image(
                image: _ProfileScreenState.resolveImage(imagePath!)!,
                fit: BoxFit.cover,
              )
            : Icon(AppIcons.person,
                size: 42,
                color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }
}

class _StatCard extends ConsumerWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final String languageCode;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = ref.watch(glassColorProvider);
    final border = ref.watch(borderColorProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border.withOpacity(0.6)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                localizeNumber('$value', languageCode),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1,
              color:
                  (isDark ? Colors.white : Colors.black).withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
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
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
