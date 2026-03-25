// lib/features/profile/profile_screen.dart
//
// ╔══════════════════════════════════════════════════════════════╗
// ║  PREMIUM PROFILE SCREEN                                       ║
// ║  Direction: Luxury editorial identity card                    ║
// ║  • Full-bleed hero with animated gradient ring avatar         ║
// ║  • Membership card header — overlapping depth layers          ║
// ║  • Stat rail: compact, data-dense, not floating cards         ║
// ║  • Info section: labeled field rows, not form inputs          ║
// ║  • Edit mode: smooth in-place field reveal                    ║
// ║  • Rotating conic gradient ring on avatar (no Lottie needed)  ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:io' show File;
import 'dart:math' show pi;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_paths.dart';
import '../../providers/feature_providers.dart' show authServiceProvider;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_icons.dart' show AppIcons;
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/number_localization.dart';
import '../../../core/security/input_sanitizer.dart';

import '../../providers/favorites_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/premium_providers.dart';

import '../../../infrastructure/persistence/services/offline_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/glass_pill_button.dart';
import '../../widgets/glass_icon_button.dart';

// ─── Extensions ───────────────────────────────────────────
extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}

// ─────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────
class _PT {
  // Elevation tiers
  static const double heroHeight = 260.0;
  static const double avatarSize = 80.0;
  static const double avatarRingGap = 3.0;
  static const double avatarRingWidth = 2.5;
  static const double avatarTotal =
      avatarSize + (avatarRingGap + avatarRingWidth) * 2;

  // Section radii
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(24));
  static const BorderRadius badgeRadius = BorderRadius.all(Radius.circular(30));

  // Typography
  static const double nameSize = 22.0;
  static const double subtitleSize = 12.0;
  static const double labelSize = 9.0;
  static const double valueSize = 14.0;
  static const double statNumSize = 20.0;
  static const double statLblSize = 8.5;

  // Animation
  static const Duration ringRotation = Duration(seconds: 5);
  static const Duration editTransition = Duration(milliseconds: 300);
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isSaving = false;
  String? _imagePath;

  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _roleCtl = TextEditingController();
  final _deptCtl = TextEditingController();

  int _favoritesCount = 0;
  int _downloadsCount = 0;

  // Avatar ring rotation
  late AnimationController _ringCtrl;
  late Animation<double> _ringAngle;

  // Section entrance stagger
  late AnimationController _entranceCtrl;
  late Animation<double> _heroFade;
  late Animation<double> _heroSlide;
  late Animation<double> _bodyFade;
  late Animation<double> _bodySlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadProfile();
    _loadStatistics();
  }

  void _initAnimations() {
    // Continuously rotating ring
    _ringCtrl = AnimationController(vsync: this, duration: _PT.ringRotation)
      ..repeat();
    _ringAngle = Tween<double>(begin: 0, end: 2 * pi).animate(_ringCtrl);

    // Entrance stagger
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _heroFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _heroSlide = Tween<double>(begin: -20, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _bodyFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _bodySlide = Tween<double>(begin: 32, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ref.read(authServiceProvider).getProfile();
      if (!mounted) return;
      setState(() {
        _nameCtl.text = data['name'] ?? '';
        _emailCtl.text = data['email'] ?? '';
        _phoneCtl.text = data['phone'] ?? '';
        _roleCtl.text = data['role'] ?? '';
        _deptCtl.text = data['department'] ?? '';
        _imagePath = data['image'];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToLoadProfile),
          backgroundColor: context.colors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
    } catch (_) {}
  }

  Future<void> _toggleEdit() async {
    if (_isEditing) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      setState(() => _isSaving = true);
      try {
        await ref
            .read(authServiceProvider)
            .updateProfile(
              name: InputSanitizer.sanitizeText(_nameCtl.text),
              email:
                  InputSanitizer.sanitizeEmail(_emailCtl.text) ??
                  _emailCtl.text,
              phone: InputSanitizer.sanitizeText(_phoneCtl.text),
              role: InputSanitizer.sanitizeText(_roleCtl.text),
              department: InputSanitizer.sanitizeText(_deptCtl.text),
              imagePath: _imagePath ?? '',
            );
        HapticFeedback.lightImpact();
        await _loadProfile();
      } catch (e) {
        debugPrint('❌ Profile save failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).failedToLoadProfile),
              backgroundColor: context.colors.errorRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
    setState(() {
      _isEditing = !_isEditing;
      _isSaving = false;
    });
  }

  Future<void> _cancelEdit() async {
    await _loadProfile();
    setState(() {
      _isEditing = false;
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _entranceCtrl.dispose();
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _roleCtl.dispose();
    _deptCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imagePath = picked.path);
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppPaths.login);
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = ref.watch(navIconColorProvider);
    final mode = ref.watch(themeProvider).mode;
    final gradient = AppGradients.getBackgroundGradient(mode);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: const AppDrawer(),
        backgroundColor: context.colors.bg,
        body: Stack(
          children: [
            // ── Ambient background ───────────────────────
            _AmbientBackground(
              accent: accent,
              isDark: isDark,
              gradient: gradient,
            ),

            // ── Scrollable body ──────────────────────────
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero SliverAppBar ────────────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ProfileSliverDelegate(
                    minHeight:
                        kToolbarHeight + MediaQuery.of(context).padding.top,
                    maxHeight:
                        _PT.heroHeight + MediaQuery.of(context).padding.top,
                    child: AnimatedBuilder(
                      animation: _entranceCtrl,
                      builder: (ctx, _) => FadeTransition(
                        opacity: _heroFade,
                        child: Transform.translate(
                          offset: Offset(0, _heroSlide.value),
                          child: _HeroHeader(
                            nameCtl: _nameCtl,
                            emailCtl: _emailCtl,
                            roleCtl: _roleCtl,
                            imagePath: _imagePath,
                            accent: accent,
                            isDark: isDark,
                            isEditing: _isEditing,
                            ringAngle: _ringAngle,
                            isPremium: ref.watch(isPremiumStateProvider),
                            loc: loc,
                            onEdit: _toggleEdit,
                            onPickImage: _pickImage,
                            onMenu: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Body sections ────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: AnimatedBuilder(
                    animation: _entranceCtrl,
                    builder: (ctx, _) => SliverOpacity(
                      opacity: _bodyFade.value.clamp(0.0, 1.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Transform.translate(
                            offset: Offset(0, _bodySlide.value),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),

                                // Stat rail
                                _StatRail(
                                  favoritesCount: _favoritesCount,
                                  downloadsCount: _downloadsCount,
                                  accent: accent,
                                  isDark: isDark,
                                  lang: ref.watch(languageCodeProvider),
                                  loc: loc,
                                ),
                                const SizedBox(height: 12),

                                // Info card
                                Form(
                                  key: _formKey,
                                  child: _InfoCard(
                                    emailCtl: _emailCtl,
                                    phoneCtl: _phoneCtl,
                                    roleCtl: _roleCtl,
                                    deptCtl: _deptCtl,
                                    isEditing: _isEditing,
                                    accent: accent,
                                    isDark: isDark,
                                    loc: loc,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Edit action row
                                AnimatedSize(
                                  duration: _PT.editTransition,
                                  curve: Curves.easeInOut,
                                  child: _isEditing
                                      ? _EditActions(
                                          isDark: isDark,
                                          accent: accent,
                                          isSaving: _isSaving,
                                          onSave: _isSaving
                                              ? null
                                              : _toggleEdit,
                                          onCancel: _cancelEdit,
                                          loc: loc,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Bottom FAB row ───────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: _BottomFabRow(
                isDark: isDark,
                accent: accent,
                loc: loc,
                onHome: () => context.go(AppPaths.home),
                onLogout: () async {
                  final router = GoRouter.of(context);
                  await ref.read(authServiceProvider).logout();
                  if (mounted) router.go(AppPaths.login);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AMBIENT BACKGROUND
// ─────────────────────────────────────────────
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({
    required this.accent,
    required this.isDark,
    required this.gradient,
  });
  final Color accent;
  final bool isDark;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient[0].withValues(alpha: isDark ? 0.95 : 0.85),
                  gradient[1].withValues(alpha: isDark ? 0.95 : 0.85),
                ],
              ),
            ),
          ),
          // Top-left hero glow
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.16 : 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-right ambient
          Positioned(
            bottom: 60,
            right: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.08 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SLIVER DELEGATE
// ─────────────────────────────────────────────
class _ProfileSliverDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileSliverDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });
  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_ProfileSliverDelegate old) =>
      old.minHeight != minHeight ||
      old.maxHeight != maxHeight ||
      old.child != child;
}

// ─────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.nameCtl,
    required this.emailCtl,
    required this.roleCtl,
    required this.imagePath,
    required this.accent,
    required this.isDark,
    required this.isEditing,
    required this.ringAngle,
    required this.isPremium,
    required this.loc,
    required this.onEdit,
    required this.onPickImage,
    required this.onMenu,
  });

  final TextEditingController nameCtl;
  final TextEditingController emailCtl;
  final TextEditingController roleCtl;
  final String? imagePath;
  final Color accent;
  final bool isDark;
  final bool isEditing;
  final Animation<double> ringAngle;
  final bool isPremium;
  final AppLocalizations loc;
  final VoidCallback onEdit;
  final VoidCallback onPickImage;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final base = isDark ? Colors.white : Colors.black;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: isDark ? 0.22 : 0.10),
                Colors.transparent,
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: accent.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Stack(
              children: [
                // ── Menu icon ────────────────────────────
                Positioned(
                  top: 12,
                  left: 16,
                  child: GlassIconButton(
                    icon: Icons.menu_rounded,
                    onPressed: onMenu,
                    isDark: isDark,
                  ),
                ),

                // ── Edit icon ────────────────────────────
                Positioned(
                  top: 12,
                  right: 16,
                  child: AnimatedSwitcher(
                    duration: _PT.editTransition,
                    child: isEditing
                        ? const SizedBox.shrink()
                        : GlassIconButton(
                            key: const ValueKey('edit'),
                            icon: Icons.edit_outlined,
                            onPressed: onEdit,
                            isDark: isDark,
                          ),
                  ),
                ),

                // ── Centred identity block ────────────────
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),

                        // Avatar + ring
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _RotatingRingAvatar(
                              imagePath: imagePath,
                              accent: accent,
                              isDark: isDark,
                              angle: ringAngle,
                            ),
                            if (isEditing)
                              GestureDetector(
                                onTap: onPickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.colors.bg,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.45),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Name
                        AnimatedSwitcher(
                          duration: _PT.editTransition,
                          child: isEditing
                              ? SizedBox(
                                  width: 200,
                                  child: TextField(
                                    controller: nameCtl,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: _PT.nameSize,
                                      fontWeight: FontWeight.w900,
                                      color: base,
                                      letterSpacing: -.5,
                                    ),
                                    decoration: InputDecoration(
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: accent.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: accent,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    cursorColor: accent,
                                  ),
                                )
                              : Text(
                                  nameCtl.text.isEmpty
                                      ? loc.userNamePlaceholder
                                      : nameCtl.text,
                                  key: const ValueKey('name-display'),
                                  style: TextStyle(
                                    fontSize: _PT.nameSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.5,
                                    color: base,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 2),

                        // Role / email
                        Text(
                          roleCtl.text.isNotEmpty
                              ? roleCtl.text
                              : emailCtl.text,
                          style: TextStyle(
                            fontSize: _PT.subtitleSize,
                            color: base.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w500,
                            letterSpacing: .2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Premium badge
                        if (isPremium) ...[
                          const SizedBox(height: 10),
                          _PremiumBadge(accent: accent, loc: loc),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ROTATING RING AVATAR
// ─────────────────────────────────────────────
class _RotatingRingAvatar extends StatelessWidget {
  const _RotatingRingAvatar({
    required this.imagePath,
    required this.accent,
    required this.isDark,
    required this.angle,
  });

  final String? imagePath;
  final Color accent;
  final bool isDark;
  final Animation<double> angle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: angle,
      builder: (_, _) {
        return SizedBox(
          width: _PT.avatarTotal,
          height: _PT.avatarTotal,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating conic ring
              Transform.rotate(
                angle: angle.value,
                child: CustomPaint(
                  size: const Size(_PT.avatarTotal, _PT.avatarTotal),
                  painter: _RingPainter(accent: accent),
                ),
              ),
              // Avatar circle
              Container(
                width: _PT.avatarSize,
                height: _PT.avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: context.colors.bg,
                    width: _PT.avatarRingGap,
                  ),
                ),
                child: ClipOval(
                  child: _resolveAvatarContent(imagePath, accent, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _resolveAvatarContent(String? path, Color accent, bool isDark) {
    if (path != null && path.isNotEmpty) {
      ImageProvider<Object>? provider;
      if (path.startsWith('http')) {
        provider = NetworkImage(path);
      } else if (path.startsWith('assets/'))
        provider = AssetImage(path);
      else {
        final f = File(path);
        if (f.existsSync()) provider = FileImage(f);
      }
      if (provider != null) {
        return Image(image: provider, fit: BoxFit.cover);
      }
    }
    return Container(
      color: accent.withValues(alpha: 0.08),
      child: Icon(
        AppIcons.person,
        size: 44,
        color: accent.withValues(alpha: 0.65),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _PT.avatarRingWidth / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _PT.avatarRingWidth
      ..shader = SweepGradient(
        colors: [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.8),
          accent,
          accent.withValues(alpha: 0.8),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.accent != accent;
}

// ─────────────────────────────────────────────
// PREMIUM BADGE
// ─────────────────────────────────────────────
class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.accent, required this.loc});
  final Color accent;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: _PT.badgeRadius,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            loc.premiumMemberBadge,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STAT RAIL  — horizontal strip, not cards
// ─────────────────────────────────────────────
class _StatRail extends ConsumerWidget {
  const _StatRail({
    required this.favoritesCount,
    required this.downloadsCount,
    required this.accent,
    required this.isDark,
    required this.lang,
    required this.loc,
  });

  final int favoritesCount;
  final int downloadsCount;
  final Color accent;
  final bool isDark;
  final String lang;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = ref.watch(glassColorProvider);
    final border = ref.watch(borderColorProvider);
    final base = isDark ? Colors.white : Colors.black;

    final stats = [
      (
        icon: Icons.favorite_rounded,
        color: context.colors.errorRed,
        value: favoritesCount,
        label: loc.favorites,
      ),
      (
        icon: Icons.download_rounded,
        color: context.colors.successGreen,
        value: downloadsCount,
        label: loc.downloaded,
      ),
      (
        icon: Icons.article_outlined,
        color: accent,
        value: 0, // articles read — extend as needed
        label: 'Read',
      ),
    ];

    return ClipRRect(
      borderRadius: _PT.cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: glass.withValues(alpha: 0.7),
            borderRadius: _PT.cardRadius,
            border: Border.all(
              color: border.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: List.generate(stats.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return VerticalDivider(
                    color: base.withValues(alpha: 0.08),
                    width: 1,
                    thickness: 1,
                    indent: 18,
                    endIndent: 18,
                  );
                }
                final s = stats[i ~/ 2];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: s.color.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Icon(s.icon, color: s.color, size: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizeNumber('${s.value}', lang),
                          style: TextStyle(
                            fontSize: _PT.statNumSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.5,
                            color: base,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: _PT.statLblSize,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                            color: base.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INFO CARD  — labeled field list
// ─────────────────────────────────────────────
class _InfoCard extends ConsumerWidget {
  const _InfoCard({
    required this.emailCtl,
    required this.phoneCtl,
    required this.roleCtl,
    required this.deptCtl,
    required this.isEditing,
    required this.accent,
    required this.isDark,
    required this.loc,
  });

  final TextEditingController emailCtl;
  final TextEditingController phoneCtl;
  final TextEditingController roleCtl;
  final TextEditingController deptCtl;
  final bool isEditing;
  final Color accent;
  final bool isDark;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = ref.watch(glassColorProvider);
    final border = ref.watch(borderColorProvider);

    final fields = [
      (
        label: loc.emailLabel,
        ctl: emailCtl,
        icon: Icons.alternate_email_rounded,
        type: TextInputType.emailAddress,
      ),
      (
        label: loc.phoneLabel,
        ctl: phoneCtl,
        icon: Icons.phone_outlined,
        type: TextInputType.phone,
      ),
      (
        label: loc.roleLabel,
        ctl: roleCtl,
        icon: Icons.badge_outlined,
        type: TextInputType.text,
      ),
      (
        label: loc.departmentLabel,
        ctl: deptCtl,
        icon: Icons.corporate_fare_rounded,
        type: TextInputType.text,
      ),
    ];

    return ClipRRect(
      borderRadius: _PT.cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: glass.withValues(alpha: 0.7),
            borderRadius: _PT.cardRadius,
            border: Border.all(
              color: border.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          // Section header
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ACCOUNT DETAILS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(fields.length, (i) {
                final f = fields[i];
                return Column(
                  children: [
                    _FieldRow(
                      label: f.label,
                      controller: f.ctl,
                      icon: f.icon,
                      keyboardType: f.type,
                      isEditing: isEditing,
                      accent: accent,
                      isDark: isDark,
                    ),
                    if (i < fields.length - 1)
                      Divider(
                        indent: 20,
                        endIndent: 20,
                        height: 0,
                        thickness: 0.5,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FIELD ROW  — read + edit in-place
// ─────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.controller,
    required this.icon,
    required this.keyboardType,
    required this.isEditing,
    required this.accent,
    required this.isDark,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isEditing;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: base.withValues(alpha: 0.32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: _PT.labelSize,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: base.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: _PT.editTransition,
                  child: isEditing
                      ? TextField(
                          key: ValueKey('field-edit-$label'),
                          controller: controller,
                          keyboardType: keyboardType,
                          style: TextStyle(
                            fontSize: _PT.valueSize,
                            fontWeight: FontWeight.w600,
                            color: base,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: accent, width: 1.5),
                            ),
                          ),
                          cursorColor: accent,
                        )
                      : Text(
                          key: ValueKey('field-read-$label'),
                          controller.text.isEmpty ? '—' : controller.text,
                          style: TextStyle(
                            fontSize: _PT.valueSize,
                            fontWeight: FontWeight.w600,
                            color: controller.text.isEmpty
                                ? base.withValues(alpha: 0.25)
                                : base,
                          ),
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

// ─────────────────────────────────────────────
// EDIT ACTIONS
// ─────────────────────────────────────────────
class _EditActions extends StatelessWidget {
  const _EditActions({
    required this.isDark,
    required this.accent,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
    required this.loc,
  });

  final bool isDark;
  final Color accent;
  final bool isSaving;
  final VoidCallback? onSave;
  final VoidCallback onCancel;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassPillButton(
            icon: Icons.close_rounded,
            label: loc.cancel,
            onPressed: onCancel,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SaveButton(
            accent: accent,
            isSaving: isSaving,
            onTap: onSave,
            label: loc.save,
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.accent,
    required this.isSaving,
    required this.onTap,
    required this.label,
  });
  final Color accent;
  final bool isSaving;
  final VoidCallback? onTap;
  final String label;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: _pressed
            ? _PT.editTransition
            : const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [widget.accent, widget.accent.withValues(alpha: 0.80)],
            ),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isSaving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else ...[
                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BOTTOM FAB ROW
// ─────────────────────────────────────────────
class _BottomFabRow extends StatelessWidget {
  const _BottomFabRow({
    required this.isDark,
    required this.accent,
    required this.loc,
    required this.onHome,
    required this.onLogout,
  });

  final bool isDark;
  final Color accent;
  final AppLocalizations loc;
  final VoidCallback onHome;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _FabTile(
                  icon: Icons.home_outlined,
                  label: loc.home,
                  isDark: isDark,
                  onTap: onHome,
                ),
              ),
              VerticalDivider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
                indent: 16,
                endIndent: 16,
              ),
              Expanded(
                child: _FabTile(
                  icon: Icons.logout_rounded,
                  label: loc.logout,
                  isDark: isDark,
                  isDestructive: true,
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabTile extends StatefulWidget {
  const _FabTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isDestructive;
  final VoidCallback onTap;

  @override
  State<_FabTile> createState() => _FabTileState();
}

class _FabTileState extends State<_FabTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? context.colors.errorRed
        : (widget.isDark
              ? Colors.white.withValues(alpha: 0.75)
              : Colors.black.withValues(alpha: 0.60));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: .1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
