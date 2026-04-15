import 'dart:io' show File;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/navigation/app_paths.dart';
import '../../../core/security/input_sanitizer.dart';
import '../../../core/utils/number_localization.dart';
import '../../../infrastructure/persistence/services/offline_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/feature_providers.dart' show authServiceProvider;
import '../../providers/language_providers.dart';
import '../../providers/premium_providers.dart';
import '../../widgets/app_drawer.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _roleCtl = TextEditingController();
  final _deptCtl = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  String _imagePath = '';
  int _favoritesCount = 0;
  int _downloadsCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _roleCtl.dispose();
    _deptCtl.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    await Future.wait([_loadProfile(), _loadStatistics()]);
  }

  Future<void> _loadProfile({bool showError = true}) async {
    try {
      final data = await ref.read(authServiceProvider).getProfile();
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;

      setState(() {
        _nameCtl.text = _nonEmpty(data['name'], user?.displayName);
        _emailCtl.text = _nonEmpty(data['email'], user?.email);
        _phoneCtl.text = data['phone'] ?? '';
        _roleCtl.text = data['role'] ?? '';
        _deptCtl.text = data['department'] ?? '';
        _imagePath = _nonEmpty(data['image'], user?.photoURL);
      });
    } catch (_) {
      if (!mounted || !showError) return;
      _showSnack(AppLocalizations.of(context).failedToLoadProfile);
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final favorites = ref.read(favoritesProvider);
      final downloads = await OfflineService.getDownloadedCount();
      if (!mounted) return;
      setState(() {
        _favoritesCount = favorites.articles.length;
        _downloadsCount = downloads;
      });
    } catch (_) {
      // Stats are useful but not required for a usable profile screen.
    }
  }

  String _nonEmpty(String? primary, String? fallback) {
    final value = (primary ?? '').trim();
    if (value.isNotEmpty) return value;
    return (fallback ?? '').trim();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _imagePath = picked.path);
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(authServiceProvider)
          .updateProfile(
            name: InputSanitizer.sanitizeText(_nameCtl.text),
            email:
                InputSanitizer.sanitizeEmail(_emailCtl.text) ??
                _emailCtl.text.trim(),
            phone: InputSanitizer.sanitizeText(_phoneCtl.text),
            role: InputSanitizer.sanitizeText(_roleCtl.text),
            department: InputSanitizer.sanitizeText(_deptCtl.text),
            imagePath: _imagePath,
          );

      HapticFeedback.lightImpact();
      await _loadProfile(showError: false);
      if (!mounted) return;
      setState(() => _isEditing = false);
      _showSnack(AppLocalizations.of(context).profileUpdated);
    } catch (_) {
      if (!mounted) return;
      _showSnack(AppLocalizations.of(context).failedToSaveProfile);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cancelEdit() async {
    await _loadProfile(showError: false);
    if (!mounted) return;
    setState(() => _isEditing = false);
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    await ref.read(authServiceProvider).logout();
    if (mounted) router.go(AppPaths.login);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppPaths.login);
      });
      return _LoadingRedirectScaffold(
        label: AppLocalizations.of(context).loading,
      );
    }

    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lang = ref.watch(languageCodeProvider);
    final isPremium = ref.watch(isPremiumStateProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        backgroundColor: scheme.surface,
        appBar: AppBar(
          elevation: 0,
          centerTitle: false,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            loc.profile,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (_isEditing)
              TextButton(
                onPressed: _isSaving ? null : _cancelEdit,
                child: Text(loc.cancel),
              )
            else
              IconButton(
                tooltip: loc.saveChanges,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => setState(() => _isEditing = true),
              ),
            const SizedBox(width: 6),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              _ProfilePanel(
                avatarPath: _imagePath,
                nameCtl: _nameCtl,
                emailCtl: _emailCtl,
                phoneCtl: _phoneCtl,
                roleCtl: _roleCtl,
                deptCtl: _deptCtl,
                favoritesCount: _favoritesCount,
                downloadsCount: _downloadsCount,
                isEditing: _isEditing,
                isSaving: _isSaving,
                isPremium: isPremium,
                languageCode: lang,
                loc: loc,
                onPickImage: _pickImage,
                onSave: _saveProfile,
                onCancel: _cancelEdit,
                onHome: () => context.go(AppPaths.home),
                onLogout: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingRedirectScaffold extends StatelessWidget {
  const _LoadingRedirectScaffold({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.avatarPath,
    required this.nameCtl,
    required this.emailCtl,
    required this.phoneCtl,
    required this.roleCtl,
    required this.deptCtl,
    required this.favoritesCount,
    required this.downloadsCount,
    required this.isEditing,
    required this.isSaving,
    required this.isPremium,
    required this.languageCode,
    required this.loc,
    required this.onPickImage,
    required this.onSave,
    required this.onCancel,
    required this.onHome,
    required this.onLogout,
  });

  final String avatarPath;
  final TextEditingController nameCtl;
  final TextEditingController emailCtl;
  final TextEditingController phoneCtl;
  final TextEditingController roleCtl;
  final TextEditingController deptCtl;
  final int favoritesCount;
  final int downloadsCount;
  final bool isEditing;
  final bool isSaving;
  final bool isPremium;
  final String languageCode;
  final AppLocalizations loc;
  final VoidCallback onPickImage;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onHome;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.40 : 0.62,
              ),
            ),
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerLow,
                scheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.34 : 0.50,
                ),
                scheme.surface,
              ],
            ),
          ),
          child: Column(
            children: [
              _IdentitySection(
                avatarPath: avatarPath,
                nameCtl: nameCtl,
                email: emailCtl.text,
                isEditing: isEditing,
                isPremium: isPremium,
                loc: loc,
                onPickImage: onPickImage,
              ),
              const _PanelDivider(),
              _StatsSection(
                favoritesCount: favoritesCount,
                downloadsCount: downloadsCount,
                languageCode: languageCode,
                loc: loc,
              ),
              const _PanelDivider(),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _DetailSection(
                  emailCtl: emailCtl,
                  phoneCtl: phoneCtl,
                  roleCtl: roleCtl,
                  deptCtl: deptCtl,
                  isEditing: isEditing,
                  loc: loc,
                ),
              ),
              const _PanelDivider(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: isEditing
                    ? _EditActions(
                        key: const ValueKey('profile-edit-actions'),
                        isSaving: isSaving,
                        loc: loc,
                        onSave: onSave,
                        onCancel: onCancel,
                      )
                    : _ProfileActions(
                        key: const ValueKey('profile-view-actions'),
                        loc: loc,
                        onHome: onHome,
                        onLogout: onLogout,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.avatarPath,
    required this.nameCtl,
    required this.email,
    required this.isEditing,
    required this.isPremium,
    required this.loc,
    required this.onPickImage,
  });

  final String avatarPath;
  final TextEditingController nameCtl;
  final String email;
  final bool isEditing;
  final bool isPremium;
  final AppLocalizations loc;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: scheme.onSurface,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.18),
            scheme.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: Row(
        children: [
          _ProfileAvatar(
            path: avatarPath,
            enabled: isEditing,
            onPickImage: onPickImage,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: isEditing
                      ? TextField(
                          key: const ValueKey('profile-name-edit'),
                          controller: nameCtl,
                          textInputAction: TextInputAction.next,
                          style: titleStyle,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.42),
                            hintText: loc.userNamePlaceholder,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: scheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('profile-name-view'),
                          width: double.infinity,
                          child: Text(
                            nameCtl.text.trim().isEmpty
                                ? loc.userNamePlaceholder
                                : nameCtl.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  email.trim().isEmpty ? loc.emailLabel : email.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (isPremium) ...[
                  const SizedBox(height: 10),
                  _PremiumBadge(label: loc.premiumMemberBadge),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.path,
    required this.enabled,
    required this.onPickImage,
  });

  final String path;
  final bool enabled;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 82,
      height: 82,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            scheme.primary,
            scheme.tertiary,
            scheme.secondary,
            scheme.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 7),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _AvatarImage(path: path),
            ),
          ),
          if (enabled)
            Positioned(
              right: -4,
              bottom: -4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.20),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPickImage,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = path.trim();
    final placeholder = Icon(
      Icons.person_outline_rounded,
      size: 38,
      color: scheme.onPrimaryContainer,
    );

    if (trimmed.isEmpty) return placeholder;

    if (trimmed.startsWith('http')) {
      return Image.network(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    return Image.file(
      File(trimmed),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.tertiaryContainer,
            scheme.tertiaryContainer.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 14,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.favoritesCount,
    required this.downloadsCount,
    required this.languageCode,
    required this.loc,
  });

  final int favoritesCount;
  final int downloadsCount;
  final String languageCode;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              icon: Icons.favorite_rounded,
              value: localizeNumber('$favoritesCount', languageCode),
              label: loc.favorites,
              accent: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.download_done_rounded,
              value: localizeNumber('$downloadsCount', languageCode),
              label: loc.downloaded,
              accent: scheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.34 : 0.48),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.18 : 0.12),
            scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.28 : 0.58,
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface.withValues(alpha: isDark ? 0.34 : 0.72),
              ),
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(icon, size: 18, color: accent),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.emailCtl,
    required this.phoneCtl,
    required this.roleCtl,
    required this.deptCtl,
    required this.isEditing,
    required this.loc,
  });

  final TextEditingController emailCtl;
  final TextEditingController phoneCtl;
  final TextEditingController roleCtl;
  final TextEditingController deptCtl;
  final bool isEditing;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _DetailField(
            icon: Icons.alternate_email_rounded,
            label: loc.emailLabel,
            controller: emailCtl,
            isEditing: isEditing,
            keyboardType: TextInputType.emailAddress,
          ),
          _DetailField(
            icon: Icons.phone_outlined,
            label: loc.phoneLabel,
            controller: phoneCtl,
            isEditing: isEditing,
            keyboardType: TextInputType.phone,
          ),
          _DetailField(
            icon: Icons.badge_outlined,
            label: loc.roleLabel,
            controller: roleCtl,
            isEditing: isEditing,
          ),
          _DetailField(
            icon: Icons.business_outlined,
            label: loc.departmentLabel,
            controller: deptCtl,
            isEditing: isEditing,
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.isEditing,
    this.keyboardType = TextInputType.text,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final value = controller.text.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEditing
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.42)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEditing
              ? scheme.primary.withValues(alpha: 0.38)
              : scheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isEditing
                  ? scheme.primaryContainer.withValues(alpha: 0.62)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 18,
                color: isEditing
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: label,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value.isEmpty ? '-' : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: value.isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditActions extends StatelessWidget {
  const _EditActions({
    required this.isSaving,
    required this.loc,
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final bool isSaving;
  final AppLocalizations loc;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSaving ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: Text(loc.cancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(loc.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.loc,
    required this.onHome,
    required this.onLogout,
    super.key,
  });

  final AppLocalizations loc;
  final VoidCallback onHome;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.home_rounded,
            label: loc.home,
            color: scheme.onSurface,
            onTap: onHome,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.logout_rounded,
            label: loc.logout,
            color: scheme.error,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.52),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.55),
    );
  }
}
