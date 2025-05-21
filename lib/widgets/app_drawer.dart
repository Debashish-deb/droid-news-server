// lib/widgets/app_drawer.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme_provider.dart';
import '../core/theme.dart';
import '../features/profile/auth_service.dart';
import '/l10n/app_localizations.dart';

class _DrawerItem {
  final IconData icon;
  final String keyName;
  final String route;
  const _DrawerItem(this.icon, this.keyName, this.route);
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  static const List<_DrawerItem> _items = [
    _DrawerItem(Icons.home, 'home', '/home'),
    _DrawerItem(Icons.article, 'newspapers', '/newspaper'),
    _DrawerItem(Icons.favorite, 'favorites', '/favorites'),
    _DrawerItem(Icons.person, 'profile', '/profile'),
    _DrawerItem(Icons.info_outline, 'about', '/about'),
    _DrawerItem(Icons.support_agent, 'supports', '/supports'),
    _DrawerItem(Icons.search, 'search', '/search'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final prov = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final gradientColors = AppGradients.getGradientColors(prov.appThemeMode);

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradientColors[0].withOpacity(0.85),
                    gradientColors[1].withOpacity(0.85),
                  ],
                ),
              ),
            ),
            // Blur overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.transparent),
            ),
            // Drawer content
            Column(
              children: [
                // Profile header
                Container(
                  decoration: prov.glassDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: const ProfileHeader(),
                ),
                _buildDivider(),
                // Menu items
                Expanded(child: _buildMenu(context, loc, textColor)),
                _buildDivider(),
                // Logout footer
                Container(
                  decoration: prov.glassDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logout button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: prov.glassColor,
                            shadowColor: Colors.black26,
                          ),
                          onPressed: () async {
                            // 1) Log out
                            await AuthService().logout();
                            // 2) Close drawer
                            Navigator.of(context).pop();
                            // 3) Navigate to login
                            context.go('/login');
                          },
                          icon: Icon(Icons.logout, color: textColor),
                          label: Text(loc.logout, style: TextStyle(color: textColor)),
                        ),
                        // Custom image on the right
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Image.asset(
                            'assets/widgets/logout_image.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, AppLocalizations loc, Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final itm = _items[i];
        final title = _title(itm.keyName, loc);
        return _DrawerTile(
          icon: itm.icon,
          title: title,
          route: itm.route,
          textColor: textColor,
        );
      },
    );
  }

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
      default:
        return key;
    }
  }

  static Widget _buildDivider() => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.transparent,
              Colors.white.withOpacity(0.5),
            ],
          ),
        ),
      );
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({Key? key}) : super(key: key);

  Future<Map<String, String>> _loadProfile() => AuthService().getProfile();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final prov = context.watch<ThemeProvider>();
    final textStyle = prov.floatingTextStyle(fontSize: 18);

    return FutureBuilder<Map<String, String>>(
      future: _loadProfile(),
      builder: (ctx, snap) {
        final imageUrl = snap.data?['image'] ?? '';
        final name = snap.connectionState == ConnectionState.waiting
            ? loc.loading
            : (snap.hasData && snap.data!['name']?.isNotEmpty == true
                ? snap.data!['name']!
                : loc.guest);

        return Container(
          height: 220,
          width: double.infinity,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: prov.glassColor,
                backgroundImage: imageUrl.isNotEmpty
                    ? (imageUrl.startsWith('https')
                        ? NetworkImage(imageUrl)
                        : FileImage(File(imageUrl))) as ImageProvider<Object>?
                    : null,
                child: imageUrl.isEmpty
                    ? Icon(Icons.person, size: 40, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(name, style: textStyle),
            ],
          ),
        );
      },
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final Color textColor;

  const _DrawerTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.route,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).uri.toString();
    final isSelected = current == route;

    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }
}
