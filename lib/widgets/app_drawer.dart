import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme_provider.dart';
import '../core/theme.dart';
import '../features/profile/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../presentation/providers/theme_providers.dart';
import '../core/services/favorites_providers.dart';
import '../presentation/providers/subscription_providers.dart';
import '../core/utils/number_localization.dart';
import '../presentation/providers/language_providers.dart';

class _DrawerItem {
  const _DrawerItem(this.icon, this.keyName, this.route);
  final IconData icon;
  final String keyName;
  final String route;
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const List<_DrawerItem> _items = <_DrawerItem>[
    _DrawerItem(Icons.home_rounded, 'home', '/home'),
    _DrawerItem(Icons.article_outlined, 'newspapers', '/newspaper'),
    _DrawerItem(Icons.favorite_rounded, 'favorites', '/favorites'),
    _DrawerItem(Icons.download_for_offline_rounded, 'offline', '/offline'),
    _DrawerItem(Icons.person_outline_rounded, 'profile', '/profile'),
    _DrawerItem(Icons.search_rounded, 'search', '/search'),
    _DrawerItem(Icons.info_outline_rounded, 'about', '/about'),
    _DrawerItem(Icons.support_agent_rounded, 'supports', '/supports'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    // Use ONLY Riverpod for theme
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final Color glassColor = ref.watch(glassColorProvider);

    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    // Use getBackgroundGradient for correct Dark Mode colors
    final List<Color> gradientColors = AppGradients.getBackgroundGradient(
      themeMode,
    );

    // DEBUG: Check what theme mode we're getting
    debugPrint('🎨 AppDrawer theme mode: $themeMode');

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 300,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Stack(
          children: <Widget>[
            // ---------------------------------
            // BACKGROUND
            // ---------------------------------
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      gradientColors
                          .map((Color c) => c.withOpacity(0.9))
                          .toList(),
                ),
              ),
            ),

            // ---------------------------------
            // MAIN CONTENT
            // ---------------------------------
            Column(
              children: <Widget>[
                const ProfileHeader(),

                _divider(),

                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    padding: const EdgeInsets.only(top: 6),
                    itemBuilder:
                        (_, int i) => _DrawerTile(
                          icon: _items[i].icon,
                          title: _title(_items[i].keyName, loc),
                          route: _items[i].route,
                          textColor: textColor,
                        ),
                  ),
                ),

                _divider(),

                _logoutPanel(context, glassColor, textColor, loc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _logoutPanel(
    BuildContext context,
    Color glassColor,
    Color txt,
    AppLocalizations loc,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // LOGOUT BUTTON
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                elevation: 4,
                backgroundColor: glassColor,
                foregroundColor: txt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: Text(loc.logout),
              onPressed: () async {
                Navigator.of(context).pop();

                await Future.delayed(const Duration(milliseconds: 200));

                await AuthService().logout();

                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    child: Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.transparent,
            Colors.white.withOpacity(0.45),
            Colors.transparent,
          ],
        ),
      ),
    ),
  );

  String _title(String key, AppLocalizations loc) {
    switch (key) {
      case 'home':
        return loc.home;
      case 'newspapers':
        return loc.newspapers;
      case 'favorites':
        return loc.favorites;
      case 'profile':
        return loc.profile;
      case 'about':
        return loc.about;
      case 'supports':
        return loc.supports;
      case 'search':
        return loc.search;
      case 'offline':
        return loc.offlineReading;
      default:
        return key;
    }
  }
}

// ============================================================
// PROFILE HEADER
// ============================================================

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});
  Future<Map<String, String>> _loadProfile() => AuthService().getProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final Color glassColor = ref.watch(glassColorProvider);
    final bool isPremium = ref.watch(isPremiumProvider);

    // Use Riverpod for favorites count
    final int favCount = ref.watch(favoritesCountProvider);

    return FutureBuilder<Map<String, String>>(
      future: _loadProfile(),
      builder: (_, AsyncSnapshot<Map<String, String>> snap) {
        final bool loading = snap.connectionState == ConnectionState.waiting;
        final String imageUrl = snap.data?['image'] ?? '';

        final String name =
            loading
                ? loc.loading
                : snap.data?['name']?.trim().isNotEmpty == true
                ? snap.data!['name']!
                : loc.guest;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
          decoration: BoxDecoration(
            color: glassColor.withOpacity(0.15),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 1. Profile Avatar with Rings
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: ref
                          .watch(borderColorProvider)
                          .withOpacity(0.3),
                      backgroundImage: _resolveImage(imageUrl),
                      onBackgroundImageError: (_, __) {},
                    ),
                  ),
                  if (isPremium)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Name & Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: -0.5,
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.black87
                                : Colors.white,
                      ),
                    ),
                  ),
                  if (isPremium) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.6),
                        ),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // 3. Stats Row (Clean)
              if (!loading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.black.withOpacity(0.04)
                            : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _buildStatItem(
                        context: context,
                        icon: Icons.bookmark_rounded,
                        count: localizeNumber(
                          favCount,
                          ref.watch(languageCodeProvider),
                        ),
                        label: loc.favorites, // Use localized "Favorites"
                        color: Colors.redAccent,
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.black12
                                : Colors.white12,
                      ),
                      _buildStatItem(
                        context: context,
                        icon:
                            isPremium
                                ? Icons.verified
                                : Icons.account_circle_outlined,
                        count: isPremium ? 'Premium' : 'Free',
                        label: loc.about,
                        color: isPremium ? Colors.amber : Colors.blueGrey,
                      ),
                    ],
                  ),
                ),

              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String count,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                color:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.black87
                        : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: (Theme.of(context).brightness == Brightness.light
                    ? Colors.black87
                    : Colors.white)
                .withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  static ImageProvider<Object>? _resolveImage(String path) {
    if (path.isEmpty) return const AssetImage('assets/default_avatar.png');
    // Check for network URLs first (Google photos, etc.)
    if (path.startsWith('http')) return NetworkImage(path);
    // Check for asset paths
    if (path.startsWith('assets/')) return AssetImage(path);
    // Check for local files
    final File file = File(path);
    if (file.existsSync()) return FileImage(file);
    // Default fallback
    return const AssetImage('assets/default_avatar.png');
  }
}

// ============================================================
// DRAWER TILE
// ============================================================

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.route,
    required this.textColor,
  });

  final IconData icon;
  final String title;
  final String route;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final String currentLocation =
        GoRouter.of(context).routeInformationProvider.value.uri.toString();

    final bool selected =
        currentLocation == route || currentLocation.startsWith('$route/');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          leading: Icon(icon, color: textColor.withOpacity(0.95)),
          title: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          trailing:
              selected
                  ? Icon(
                    Icons.arrow_right_rounded,
                    color: textColor.withOpacity(0.8),
                  )
                  : null,
          onTap: () {
            Navigator.of(context).pop();

            if (!selected) {
              Future.delayed(const Duration(milliseconds: 180), () {
                if (context.mounted) context.go(route);
              });
            }
          },
        ),
      ),
    );
  }
}
