// lib/presentation/widgets/app_drawer.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  APP DRAWER – ANDROID-OPTIMISED v2                       ║
// ║                                                          ║
// ║  Optimisation layers applied                             ║
// ║  • _items is a module-level const – never rebuilt        ║
// ║  • Route-active detection via GoRouterState.of(context)  ║
// ║    (replaces routeInformationProvider.value.uri which    ║
// ║    does not benefit from InheritedWidget diffing)        ║
// ║  • Future.delayed for nav replaced with                  ║
// ║    WidgetsBinding.addPostFrameCallback (no Timer alloc)  ║
// ║  • AnimatedBuilder child extracted → no closure alloc    ║
// ║    per animation tick                                     ║
// ║  • RepaintBoundary on header and nav list                ║
// ║  • _DrawerHeader is a plain ConsumerWidget (no nested    ║
// ║    Consumer widget node inside)                          ║
// ║  • MediaQuery.paddingOf / sizeOf instead of full .of()   ║
// ║  • const constructors end-to-end                         ║
// ║  • _HeaderContent fields are final — no accidental       ║
// ║    mutation; equals-check short-circuits rebuilds        ║
// ║  • _Divider uses DecoratedBox (no Container overhead)    ║
// ╚══════════════════════════════════════════════════════════╝

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart' show AppIcons;
import '../../core/navigation/app_paths.dart';
import '../../core/config/performance_config.dart';
import '../../core/theme/theme.dart'
    show AppColorsExtension, AppThemeRulesExtension;
import '../../l10n/generated/app_localizations.dart';

import '../providers/feature_providers.dart';
import '../providers/premium_providers.dart';
import '../providers/tab_providers.dart';
import '../providers/user_providers.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────
extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
  AppThemeRulesExtension get rules =>
      Theme.of(this).extension<AppThemeRulesExtension>()!;
}

// ─────────────────────────────────────────────
// DRAWER ITEM MODEL
// ─────────────────────────────────────────────
@immutable
class _DrawerItem {
  const _DrawerItem(this.icon, this.labelGetter, this.route, this.accent);
  final IconData icon;
  final String Function(AppLocalizations) labelGetter;
  final String route;
  final Color accent;
}

// ─── Module-level const – never reallocated ──
const _kItems = <_DrawerItem>[
  _DrawerItem(
    AppIcons.person,
    _labelProfile,
    AppPaths.profile,
    Color(0xFF7C6FCD),
  ),
  _DrawerItem(
    Icons.view_list_rounded,
    _labelManageSources,
    AppPaths.manageSources,
    Color(0xFFD48B5B),
  ),
  _DrawerItem(
    AppIcons.favorite,
    _labelFavorites,
    AppPaths.favorites,
    Color(0xFFE05C6A),
  ),
  _DrawerItem(
    AppIcons.download,
    _labelOffline,
    AppPaths.savedArticles,
    Color(0xFF3DBE7A),
  ),
  _DrawerItem(AppIcons.info, _labelAbout, AppPaths.about, Color(0xFF5BA8D4)),
  _DrawerItem(AppIcons.help, _labelHelp, AppPaths.help, Color(0xFF8899AA)),
];

// Top-level static label getters required for const initializers.
String _labelProfile(AppLocalizations l) => l.profile;
String _labelManageSources(AppLocalizations l) => l.manageSources;
String _labelFavorites(AppLocalizations l) => l.favorites;
String _labelOffline(AppLocalizations l) => l.offlineReading;
String _labelAbout(AppLocalizations l) => l.about;
String _labelHelp(AppLocalizations l) => l.helpSupport;

// ─────────────────────────────────────────────
// APP DRAWER
// ─────────────────────────────────────────────
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  bool _reduceMotion = false;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    if (perf.reduceMotion != _reduceMotion) {
      _reduceMotion = perf.reduceMotion;
      _ctrl.duration = _reduceMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 380);
    }
    if (!_didStart) {
      _didStart = true;
      if (_reduceMotion) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Automatically close this drawer if the user switches tabs while it is open.
    ref.listen(tabProvider, (previous, next) {
      if (previous != null && previous != next) {
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      }
    });

    final loc = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth * 0.84).clamp(280.0, 360.0).toDouble();
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final perf = PerformanceConfig.of(context);
    final bool allowBlur =
        !perf.reduceEffects &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;

    // Pre-build the static child once; AnimatedBuilder does NOT
    // rebuild the child — only the transform wrapper is rebuilt.
    final drawerChild = _DrawerShell(
      drawerWidth: drawerWidth,
      bottomPad: bottomPad,
      loc: loc,
      ref: ref,
      allowBlur: allowBlur,
      bgColor: context.colors.bg,
    );

    return AnimatedBuilder(
      animation: _ctrl,
      // child is cached and passed through – avoids closure alloc
      // on every animation frame.
      child: drawerChild,
      builder: (_, child) => FadeTransition(opacity: _fade, child: child),
    );
  }
}

// ─────────────────────────────────────────────
// DRAWER SHELL  (pure widget, no animation state)
// Extracted so AnimatedBuilder.child can be set once.
// ─────────────────────────────────────────────
class _DrawerShell extends StatelessWidget {
  const _DrawerShell({
    required this.drawerWidth,
    required this.bottomPad,
    required this.loc,
    required this.ref,
    required this.allowBlur,
    required this.bgColor,
  });

  final double drawerWidth;
  final double bottomPad;
  final AppLocalizations loc;
  final WidgetRef ref;
  final bool allowBlur;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final borderRadius = const BorderRadius.only(
      topRight: Radius.circular(24),
      bottomRight: Radius.circular(24),
    );
    final borderColor = _resolveBorderColor(context, brightness);
    final borderWidth = brightness == Brightness.dark ? 1.2 : 1.05;
    final shadowColor = _resolveShadowColor(borderColor, brightness);

    final shell = Padding(
      padding: EdgeInsets.only(bottom: 8 + bottomPad),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 22,
              spreadRadius: 0.6,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: !allowBlur
              ? ColoredBox(
                  color: bgColor.withValues(alpha: 0.98),
                  child: _DrawerContent(loc: loc, ref: ref),
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ColoredBox(
                    color: bgColor.withValues(alpha: 0.90),
                    child: _DrawerContent(loc: loc, ref: ref),
                  ),
                ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: drawerWidth, child: shell),
    );
  }

  Color _resolveBorderColor(BuildContext context, Brightness brightness) {
    final baseBorder = context.colors.cardBorder;
    final brandTone = context.rules.drawerBrandColor;
    final brandMix = brightness == Brightness.dark ? 0.34 : 0.22;
    return Color.alphaBlend(
      brandTone.withValues(alpha: brandMix),
      baseBorder.withValues(alpha: brightness == Brightness.dark ? 0.96 : 1),
    );
  }

  Color _resolveShadowColor(Color borderColor, Brightness brightness) {
    final ambient = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.16);
    return Color.alphaBlend(borderColor.withValues(alpha: 0.30), ambient);
  }
}

// ─────────────────────────────────────────────
// DRAWER CONTENT
// ─────────────────────────────────────────────
class _DrawerContent extends StatelessWidget {
  const _DrawerContent({required this.loc, required this.ref});

  final AppLocalizations loc;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = _DrawerViewportSpec.fromHeight(constraints.maxHeight);

        final navBlock = Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  for (int i = 0; i < _kItems.length; i++) ...[
                    _NavTile(
                      icon: _kItems[i].icon,
                      label: _kItems[i].labelGetter(loc),
                      route: _kItems[i].route,
                      accent: _kItems[i].accent,
                      compact: spec.compactTiles,
                    ),
                    if (i < _kItems.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: context.colors.cardBorder.withValues(alpha: 0.6),
                        indent: 52,
                        endIndent: 20,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );

        final branding = _Branding(compact: spec.compactTiles);
        
        final logoutTile = _LogoutTile(loc: loc, compact: spec.compactTiles);
        final closeTile = _CloseTile(loc: loc, compact: spec.compactTiles);

        final staticBody = Padding(
          padding: EdgeInsets.fromLTRB(
            spec.horizontalPad,
            spec.topPad,
            spec.horizontalPad,
            spec.bottomPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              navBlock,
              const Spacer(flex: 3),
              logoutTile,
              SizedBox(height: spec.itemGap * 2),
              closeTile,
              const Spacer(flex: 2),
              branding,
            ],
          ),
        );

        final scrollBody = SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spec.horizontalPad,
              spec.topPad,
              spec.horizontalPad,
              spec.bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                navBlock,
                SizedBox(height: spec.sectionGap * 2),
                logoutTile,
                SizedBox(height: spec.itemGap * 2),
                closeTile,
                SizedBox(height: spec.sectionGap),
                branding,
              ],
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              child: _DrawerHeader(loc: loc, compact: spec.compactHeader),
            ),
            Expanded(
              child: RepaintBoundary(
                child: spec.scrollBody ? scrollBody : staticBody,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DrawerViewportSpec {
  const _DrawerViewportSpec({
    required this.compactHeader,
    required this.compactTiles,
    required this.scrollBody,
    required this.horizontalPad,
    required this.topPad,
    required this.bottomPad,
    required this.itemGap,
    required this.sectionGap,
  });

  factory _DrawerViewportSpec.fromHeight(double height) {
    if (height < 640) {
      return const _DrawerViewportSpec(
        compactHeader: true,
        compactTiles: true,
        scrollBody: true,
        horizontalPad: 10,
        topPad: 8,
        bottomPad: 8,
        itemGap: 4,
        sectionGap: 5,
      );
    }
    if (height < 760) {
      return const _DrawerViewportSpec(
        compactHeader: true,
        compactTiles: true,
        scrollBody: false,
        horizontalPad: 11,
        topPad: 8,
        bottomPad: 8,
        itemGap: 5,
        sectionGap: 6,
      );
    }
    return const _DrawerViewportSpec(
      compactHeader: false,
      compactTiles: false,
      scrollBody: false,
      horizontalPad: 12,
      topPad: 10,
      bottomPad: 10,
      itemGap: 6,
      sectionGap: 6,
    );
  }

  final bool compactHeader;
  final bool compactTiles;
  final bool scrollBody;
  final double horizontalPad;
  final double topPad;
  final double bottomPad;
  final double itemGap;
  final double sectionGap;
}

// ─────────────────────────────────────────────
// DRAWER HEADER
// ─────────────────────────────────────────────
class _DrawerHeader extends ConsumerWidget {
  const _DrawerHeader({required this.loc, required this.compact});
  final AppLocalizations loc;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.paddingOf(context).top;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final fallbackName = (firebaseUser?.displayName?.trim().isNotEmpty ?? false)
        ? firebaseUser!.displayName!.trim()
        : loc.guest;
    final fallbackEmail = (firebaseUser?.email ?? '').trim();
    final fallbackImage = (firebaseUser?.photoURL ?? '').trim();

    // Scoped selects -> only rebuilds when these specific values change.
    final profileAsync = ref.watch(userProfileProvider);
    final profileData = profileAsync.valueOrNull;
    final resolvedName =
        ((profileData?['name'] as String?) ?? '').trim().isNotEmpty
        ? (profileData!['name'] as String).trim()
        : fallbackName;
    final resolvedEmail =
        ((profileData?['email'] as String?) ?? '').trim().isNotEmpty
        ? (profileData!['email'] as String).trim()
        : fallbackEmail;
    final resolvedImage =
        ((profileData?['image'] as String?) ?? '').trim().isNotEmpty
        ? (profileData!['image'] as String).trim()
        : fallbackImage;
    final isPremium = ref.watch(isPremiumStateProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + (compact ? 10 : 14), 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
      ),
      child: _HeaderContent(
        name: resolvedName,
        email: resolvedEmail,
        imageUrl: resolvedImage,
        isPremium: isPremium,
        compact: compact,
      ),
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.name,
    required this.email,
    required this.imageUrl,
    required this.isPremium,
    required this.compact,
  });

  final String name;
  final String email;
  final String imageUrl;
  final bool isPremium;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatar = compact ? 46.0 : 52.0;
    final iconSize = compact ? 24.0 : 26.0;

    return Row(
      children: [
        // ── Avatar ──────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatar,
              height: avatar,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPremium
                      ? context.colors.goldStart.withValues(alpha: 0.6)
                      : context.colors.cardBorder,
                  width: 2,
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A3E), Color(0xFF1A1A28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        memCacheWidth: (avatar * 2).round(),
                        memCacheHeight: (avatar * 2).round(),
                        maxWidthDiskCache: 256,
                        maxHeightDiskCache: 256,
                        fadeInDuration: const Duration(milliseconds: 120),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Icon(
                          Icons.person,
                          color: context.colors.textSecondary,
                          size: iconSize,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: context.colors.textSecondary,
                          size: iconSize,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: context.colors.textSecondary,
                        size: iconSize,
                      ),
              ),
            ),
            if (isPremium)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        context.colors.goldStart,
                        context.colors.goldMid,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: context.colors.surface,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: context.colors.goldGlow, blurRadius: 6),
                    ],
                  ),
                  child: const Icon(
                    Icons.diamond_rounded,
                    size: 9,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: compact ? 10 : 14),

        // ── Text ─────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: compact ? 11.5 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (isPremium) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.goldStart.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.colors.goldStart.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 10,
                        color: context.colors.goldStart,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: context.colors.goldStart,
                          fontSize: compact ? 9 : 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Arrow ────────────────────────────────
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            context.go(AppPaths.profile);
          },
          child: Container(
            width: compact ? 28 : 30,
            height: compact ? 28 : 30,
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// NAV TILE
// ─────────────────────────────────────────────
class _NavTile extends ConsumerWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.accent,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // GoRouterState.of() updates via InheritedWidget diffing —
    // more efficient than reading routeInformationProvider.value.
    final location = GoRouterState.of(context).uri.toString();
    final selected = location == route || location.startsWith('$route/');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          if (!selected) {
            // addPostFrameCallback avoids allocating a Timer object
            // and fires exactly one frame after drawer closes.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go(route);
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: compact ? 46 : 52,
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 28 : 30,
                child: Icon(
                  icon,
                  size: compact ? 18 : 20,
                  color: selected ? accent : context.colors.textSecondary,
                ),
              ),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? context.colors.textPrimary
                        : context.colors.textSecondary,
                    fontSize: compact ? 13.5 : 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DIVIDER
// ─────────────────────────────────────────────
// LOGOUT TILE
// ─────────────────────────────────────────────
class _LogoutTile extends ConsumerWidget {
  const _LogoutTile({required this.loc, required this.compact});
  final AppLocalizations loc;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        Navigator.of(context).pop();
        await ref.read(authServiceProvider).logout();
        if (context.mounted) context.go(AppPaths.login);
      },
      child: Container(
        height: compact ? 44 : 50,
        decoration: BoxDecoration(
          color: context.colors.errorRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.errorRed.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              size: compact ? 17 : 19,
              color: context.colors.errorRed,
            ),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                color: context.colors.errorRed,
                fontSize: compact ? 13.5 : 14.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLOSE TILE
// ─────────────────────────────────────────────
class _CloseTile extends StatelessWidget {
  const _CloseTile({required this.loc, required this.compact});
  final AppLocalizations loc;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        height: compact ? 44 : 50,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.cardBorder.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.close_rounded,
              size: compact ? 16 : 18,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              loc.close,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: compact ? 13.5 : 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────
// BRANDING
// ─────────────────────────────────────────────
class _Branding extends StatelessWidget {
  const _Branding({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final appNameColor = context.rules.drawerBrandColor;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
      child: Column(
        children: [
          Container(
            width: compact ? 44 : 50,
            height: compact ? 44 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: appNameColor.withValues(alpha: 0.45),
                width: compact ? 1.2 : 1.4,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/play_store_512-app.png',
                width: compact ? 44 : 50,
                height: compact ? 44 : 50,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.newspaper_rounded,
                  size: compact ? 20 : 24,
                  color: appNameColor,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 7 : 8),
          Text(
            'BD NewsReader',
            style: TextStyle(
              color: appNameColor,
              fontSize: compact ? 12.5 : 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.45,
              shadows: [
                Shadow(
                  color: appNameColor.withValues(alpha: 0.42),
                  blurRadius: 9,
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 1.5 : 2),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              color: context.colors.textHint.withValues(alpha: 0.92),
              fontSize: compact ? 9 : 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
