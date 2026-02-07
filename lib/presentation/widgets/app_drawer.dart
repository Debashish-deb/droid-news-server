import 'dart:io';
import 'dart:async';
import 'dart:ui'; 

import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/app_paths.dart';
import '../../core/enums/theme_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/feature_providers.dart';
import '../providers/premium_providers.dart';
import '../providers/theme_providers.dart';
import '../providers/user_providers.dart';
import 'glass_icon_button.dart';
import '../../core/performance_config.dart';

class _DrawerItem {
  const _DrawerItem(this.icon, this.labelGetter, this.route, this.color);
  final IconData icon;
  final String Function(AppLocalizations) labelGetter;
  final String route;
  final Color color;
}

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  bool _reduceMotion = false;
  bool _reduceEffects = false;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.8, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    if (perf.reduceMotion != _reduceMotion || perf.reduceEffects != _reduceEffects) {
      _reduceMotion = perf.reduceMotion;
      _reduceEffects = perf.reduceEffects;
      _animationController.duration = _reduceMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 400);
    }

    if (_reduceMotion) {
      _animationController.value = 1.0;
      _didStart = true;
    } else if (!_didStart) {
      _didStart = true;
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static List<_DrawerItem> _getItems(AppLocalizations loc) => [
    _DrawerItem(
      AppIcons.person,
      (l) => l.profile,
      AppPaths.profile,
      const Color(0xFF6A5ACD), // Slate Blue
    ),
    _DrawerItem(
      AppIcons.favorite,
      (l) => l.favorites,
      AppPaths.favorites,
      const Color(0xFFE74C3C), // Alizarin Red
    ),
    _DrawerItem(
      AppIcons.download,
      (l) => l.offlineReading,
      AppPaths.savedArticles,
      const Color(0xFF3498DB), // Peter River Blue
    ),
    _DrawerItem(
      AppIcons.more,
      (l) => l.extras,
      AppPaths.extras,
      const Color(0xFF2ECC71), // Emerald Green
    ),
    _DrawerItem(
      AppIcons.info,
      (l) => l.about,
      AppPaths.about,
      const Color(0xFFF39C12), // Sunflower Yellow
    ),
    _DrawerItem(
      AppIcons.help,
      (l) => l.helpSupport,
      AppPaths.help,
      const Color(0xFF9B59B6), // Amethyst Purple
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final items = _getItems(loc);
    final selectionColor = ref.watch(navIconColorProvider);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value * MediaQuery.of(context).size.width * 0.28, 0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        margin: const EdgeInsets.only(bottom: 120), // Float above bottom nav (increased for safety)
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            child: Stack(
              children: [
                // 1. OLED Deep Base
                Container(color: isDark ? const Color(0xFF030303) : const Color(0xFFF8F9FA)),

                // 2. Tech Mesh Gradients
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          // Primary Mesh Glow
                          Positioned(
                            top: -100,
                            right: -50,
                            child: Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    selectionColor.withOpacity(isDark ? 0.15 : 0.1),
                                    selectionColor.withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Secondary Accent Glow
                          Positioned(
                            bottom: 50,
                            left: -100,
                            child: Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    (ref.watch(currentThemeModeProvider) == AppThemeMode.bangladesh ? const Color(0xFFFF0000) : selectionColor).withOpacity(isDark ? 0.1 : 0.05),
                                    (ref.watch(currentThemeModeProvider) == AppThemeMode.bangladesh ? const Color(0xFFFF0000) : selectionColor).withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 3. Ultra Glass Overlay
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.03 : 0.02),
                            (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.01 : 0.01),
                          ],
                        ),
                        border: Border(
                          right: BorderSide(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Main content
                Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ProfileHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 8), // Reduced from 16
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DrawerSection(title: loc.profile.toUpperCase()),
                                ...items.take(3).map((item) => _DrawerTile(
                                  icon: item.icon,
                                  title: item.labelGetter(loc),
                                  route: item.route,
                                  color: item.color,
                                )),
                                const SizedBox(height: 8), // Reduced from 16
                                _DrawerSection(title: loc.extras.toUpperCase()),
                                ...items.skip(3).map((item) => _DrawerTile(
                                  icon: item.icon,
                                  title: item.labelGetter(loc),
                                  route: item.route,
                                  color: item.color,
                                )),
                                const SizedBox(height: 12), // Reduced from 24
                                _logoutPanel(context, ref, loc),
                                const SizedBox(height: 12), // Added gap for close button
                                // Integrated Close Button at bottom
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: ListTile(
                                    onTap: () {
                                      _animationController.reverse().then((_) {
                                        if (mounted && Navigator.of(context).canPop()) {
                                          Navigator.of(context).pop();
                                        }
                                      });
                                    },
                                    leading: Icon(Icons.close_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5), size: 22),
                                    title: Text(
                                      loc.close,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 24), // Reduced from 48
                                _buildBranding(context, isDark),
                                const SizedBox(height: 20), // Reduced from 40
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/app_logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'BD NewsReader',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
            ),
          ),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutPanel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        onTap: () async {
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          await ref.read(authServiceProvider).logout();
          if (context.mounted) context.go('/login');
        },
        leading: Icon(AppIcons.logout, color: Colors.redAccent.withOpacity(0.8), size: 22),
        title: Text(
          loc.logout,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.redAccent,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final bool isPremium = ref.watch(isPremiumProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final selectionColor = ref.watch(navIconColorProvider);
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerColor = themeMode == AppThemeMode.bangladesh
        ? const Color(0xFF006A4E)
        : isDark
            ? AppColors.darkSurface // Unified Slate-Mocha for dark mode contrast
            : selectionColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(40)),
      ),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 12, 24, 16), // Reduced padding
      child: userProfileAsync.when(
        data: (data) {
          final String name = data['name']?.trim().isNotEmpty == true ? data['name']! : loc.guest;
          final String email = data['email'] ?? '';
          final String imageUrl = data['image'] ?? '';

          return Row(
            children: [
              // Avatar
              Container(
                width: 54, // Reduced from 64
                height: 54, // Reduced from 64
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Icon(Icons.person, color: selectionColor, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, // Reduced from 20
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12, // Reduced from 14
                        ),
                      ),
                    if (isPremium)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PREMIUM',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              // Chevron or Edit Icon
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.7)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (_, __) => Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.error)),
            const SizedBox(width: 16),
            Text(loc.guest, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  static ImageProvider<Object>? resolveImage(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('http')) return NetworkImage(path);
    if (path.startsWith('assets/')) return AssetImage(path);
    final File file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 6), // Reduced from 8, 12
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withOpacity(0.5) 
              : Colors.black.withOpacity(0.4),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerTile extends ConsumerWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String currentLocation = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    final bool selected = currentLocation == route || 
        (route != '/' && currentLocation.startsWith('$route/'));

    final selectionColor = ref.watch(navIconColorProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // Reduced from 2
      child: ListTile(
        onTap: () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          if (!selected) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (context.mounted) {
                final String currentPath = GoRouter.of(context).routeInformationProvider.value.uri.toString();
                if (currentPath == AppPaths.home || currentPath == '/') {
                  context.push(route);
                } else {
                  context.pushReplacement(route);
                }
              }
            });
          }
        },
        selected: selected,
        selectedTileColor: selectionColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          size: 22,
          color: selected ? selectionColor : color.withOpacity(0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected 
                ? selectionColor 
                : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
            fontFamily: AppTypography.fontFamily,
          ),
        ),
        trailing: selected 
            ? Icon(Icons.chevron_right_rounded, color: selectionColor, size: 20)
            : Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 20),
      ),
    );
  }
}
