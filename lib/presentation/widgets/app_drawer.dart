import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart' show AppIcons;
import '../../core/design_tokens.dart';
import '../../core/app_paths.dart';
import '../../core/enums/theme_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/performance_config.dart';

import '../providers/feature_providers.dart';
import '../providers/premium_providers.dart';
import '../providers/theme_providers.dart';
import '../providers/user_providers.dart';

/// Drawer Item Model
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

  static List<_DrawerItem> _getDrawerItems(AppLocalizations loc) => [
    _DrawerItem(
      AppIcons.person,
      (l) => l.profile,
      AppPaths.profile,
      const Color(0xFF6A5ACD),
    ),
    _DrawerItem(
      AppIcons.favorite,
      (l) => l.favorites,
      AppPaths.favorites,
      const Color(0xFFE74C3C),
    ),
    _DrawerItem(
      AppIcons.download,
      (l) => l.offlineReading,
      AppPaths.savedArticles,
      const Color(0xFF2ECC71),
    ),
    _DrawerItem(
      AppIcons.info,
      (l) => l.about,
      AppPaths.about,
      const Color(0xFF95A5A6),
    ),
    _DrawerItem(
      AppIcons.help,
      (l) => l.helpSupport,
      AppPaths.help,
      const Color(0xFF34495E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final drawerItems = _getDrawerItems(loc);
    final selectionColor = ref.watch(navIconColorProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final Color drawerSurface = theme.colorScheme.surface;
    final Color accentGlow = Color.alphaBlend(
      selectionColor.withOpacity(isDark ? 0.12 : 0.08),
      drawerSurface,
    );

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
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 20 + bottomPadding,
            width: MediaQuery.of(context).size.width * 0.75,
            child: Container(
              decoration: BoxDecoration(
                color: drawerSurface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                border: Border.all(
                  color: accentGlow,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                    blurRadius: 30,
                    offset: const Offset(5, 0),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, loc, selectionColor),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        children: [
                          ...drawerItems.map((item) => _DrawerTile(
                            icon: item.icon,
                            title: item.labelGetter(loc),
                            route: item.route,
                            color: item.color,
                          )),
                          const SizedBox(height: 8),
                          _buildLogout(context, loc),
                          const SizedBox(height: 8),
                          _buildCloseButton(context, loc),
                          const SizedBox(height: 12),
                          _buildBranding(context, isDark),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations loc, Color selectionColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(currentThemeModeProvider);
    final headerColor = themeMode == AppThemeMode.bangladesh
        ? const Color(0xFF006A4E)
        : isDark
            ? AppColors.darkSurface
            : selectionColor;

    return Container(
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 
        MediaQuery.of(context).padding.top + 16, 
        20, 
        20
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final userProfileAsync = ref.watch(userProfileProvider);
          final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;
          
          return userProfileAsync.when(
            data: (data) {
              final name = data['name']?.isNotEmpty == true ? data['name']! : loc.guest;
              final email = data['email'] ?? '';
              final imageUrl = data['image'] ?? '';

              return Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                    ),
                    child: ClipOval(
                      child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : Icon(Icons.person, color: headerColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        if (isPremium)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(color: Colors.white),
            error: (_, __) => Text(loc.guest, style: const TextStyle(color: Colors.white)),
          );
        },
      ),
    );
  }

  Widget _buildLogout(BuildContext context, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        onTap: () async {
          Navigator.of(context).pop();
          await ref.read(authServiceProvider).logout();
          if (context.mounted) context.go('/login');
        },
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        onTap: () => Navigator.of(context).pop(),
        leading: const Icon(Icons.close),
        title: Text(loc.close),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBranding(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
                BoxShadow(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  offset: const Offset(0, -1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Image.asset(
              'assets/app_logo.png',
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => Icon(
                Icons.newspaper,
                size: 40,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'BD NewsReader',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
              shadows: [
                Shadow(
                  color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                  offset: const Offset(0, 0.5),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
            ),
          ),
        ],
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
    final currentLocation = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    final selected = currentLocation == route || currentLocation.startsWith('$route/');
    final selectionColor = ref.watch(navIconColorProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () {
          Navigator.of(context).pop();
          if (!selected) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (context.mounted) {
                context.push(route);
              }
            });
          }
        },
        selected: selected,
        selectedTileColor: selectionColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? selectionColor.withOpacity(0.1) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? selectionColor : color,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            color: selected ? selectionColor : null,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}