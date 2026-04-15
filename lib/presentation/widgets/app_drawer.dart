import 'dart:ui';
import '../../core/theme/theme_skeleton.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'optimized_cached_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart' show AppIcons;
import '../../core/navigation/app_paths.dart';
import '../../core/config/performance_config.dart';
import '../../core/theme/theme.dart'
    show AppColorsExtension, AppThemeRulesExtension;
import '../../l10n/generated/app_localizations.dart';

import '../providers/premium_providers.dart';
import '../providers/tab_providers.dart';
import '../providers/user_providers.dart';
import 'platform_surface_treatment.dart';

// DESIGN TOKENS

extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
  AppThemeRulesExtension get rules =>
      Theme.of(this).extension<AppThemeRulesExtension>()!;
}

bool _closeDrawerIfOpen(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold == null) return false;
  if (scaffold.isDrawerOpen) {
    Navigator.of(context).pop();
    return true;
  }
  if (scaffold.isEndDrawerOpen) {
    Navigator.of(context).pop();
    return true;
  }
  return false;
}

bool _isSelectedDrawerRoute(String location, String route) =>
    location == route || location.startsWith('$route/');

String _currentDrawerLocation(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.toString();
  } catch (_) {
    return '';
  }
}

void _navigateFromDrawer(
  BuildContext context, {
  required String route,
  required bool selected,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final router = GoRouter.of(context);
  _closeDrawerIfOpen(context);
  if (selected) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    router.go(route);
  });
}

// DRAWER ITEM MODEL

@immutable
class _DrawerItem {
  const _DrawerItem(this.icon, this.labelGetter, this.route, this.accent);
  final IconData icon;
  final String Function(AppLocalizations) labelGetter;
  final String route;
  final Color accent;
}

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
    AppPaths.offline,
    Color(0xFF3DBE7A),
  ),
  _DrawerItem(AppIcons.info, _labelAbout, AppPaths.about, Color(0xFF5BA8D4)),
  _DrawerItem(AppIcons.help, _labelHelp, AppPaths.help, Color(0xFF8899AA)),
];

String _labelProfile(AppLocalizations l) => l.profile;
String _labelManageSources(AppLocalizations l) => l.manageSources;
String _labelFavorites(AppLocalizations l) => l.favorites;
String _labelOffline(AppLocalizations l) => l.offlineReading;
String _labelAbout(AppLocalizations l) => l.about;
String _labelHelp(AppLocalizations l) => l.helpSupport;

// APP DRAWER

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  ProviderSubscription<int>? _tabSubscription;

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
    _tabSubscription = ref.listenManual<int>(currentTabIndexProvider, (
      previous,
      next,
    ) {
      if (!mounted || previous == null || previous == next) return;
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null &&
          ModalRoute.of(context)?.isCurrent == true &&
          (scaffold.isDrawerOpen || scaffold.isEndDrawerOpen)) {
        _closeDrawerIfOpen(context);
      }
    });
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
    _tabSubscription?.close();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth * 0.84).clamp(280.0, 360.0).toDouble();
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final perf = PerformanceConfig.of(context);
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final bool allowBlur =
        !preferMaterialChrome &&
        !perf.reduceEffects &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;

    final drawerChild = _DrawerShell(
      drawerWidth: drawerWidth,
      bottomPad: bottomPad,
      loc: loc,
      allowBlur: allowBlur,
      bgColor: context.colors.bg,
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        child: drawerChild,
        builder: (_, child) => FadeTransition(opacity: _fade, child: child),
      ),
    );
  }
}

// DRAWER SHELL  (pure widget, no animation state)

class _DrawerShell extends StatelessWidget {
  const _DrawerShell({
    required this.drawerWidth,
    required this.bottomPad,
    required this.loc,
    required this.allowBlur,
    required this.bgColor,
  });

  final double drawerWidth;
  final double bottomPad;
  final AppLocalizations loc;
  final bool allowBlur;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceConfig.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bool lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final brightness = Theme.of(context).brightness;
    final borderRadius = BorderRadius.only(
      topRight: ThemeSkeleton.shared.radius(24),
      bottomRight: ThemeSkeleton.shared.radius(24),
    );
    final borderColor = _resolveBorderColor(context, brightness);
    final borderWidth = brightness == Brightness.dark ? 1.2 : 1.05;
    final shadowColor = _resolveShadowColor(borderColor, brightness);
    final shellSurface = preferMaterialChrome
        ? materialSurfaceOverlayColor(
            scheme,
            surfaceAlpha: 0.98,
            tintAlpha: 0.05,
          )
        : bgColor.withValues(alpha: 0.98);

    final shell = Padding(
      padding: ThemeSkeleton.shared.insetsOnly(bottom: 8 + bottomPad),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: lowEffects
              ? const <BoxShadow>[]
              : [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 12,
                    spreadRadius: 0.6,
                    offset: const Offset(2, 0),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: !allowBlur
              ? ColoredBox(
                  color: shellSurface,
                  child: _DrawerContent(loc: loc),
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: ColoredBox(
                    color: bgColor.withValues(alpha: 0.90),
                    child: _DrawerContent(loc: loc),
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

// DRAWER CONTENT

class _DrawerContent extends StatelessWidget {
  const _DrawerContent({required this.loc});

  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    final location = _currentDrawerLocation(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = _DrawerViewportSpec.fromHeight(constraints.maxHeight);

        final navBlock = Padding(
          padding: ThemeSkeleton.insetsV8,
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: ThemeSkeleton.shared.circular(20),
              boxShadow: lowEffects
                  ? const <BoxShadow>[]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: ThemeSkeleton.shared.circular(20),
              child: Column(
                children: [
                  for (int i = 0; i < _kItems.length; i++) ...[
                    _NavTile(
                      icon: _kItems[i].icon,
                      label: _kItems[i].labelGetter(loc),
                      route: _kItems[i].route,
                      selected: _isSelectedDrawerRoute(
                        location,
                        _kItems[i].route,
                      ),
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

        final staticBody = Padding(
          padding: EdgeInsets.fromLTRB(
            spec.horizontalPad,
            spec.topPad,
            spec.horizontalPad,
            spec.bottomPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [navBlock, const Spacer(flex: 5), branding],
          ),
        );

        final scrollBody = CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                spec.horizontalPad,
                spec.topPad,
                spec.horizontalPad,
                0,
              ),
              sliver: SliverToBoxAdapter(child: navBlock),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  spec.horizontalPad,
                  spec.sectionGap * 2,
                  spec.horizontalPad,
                  spec.bottomPad,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: branding,
                ),
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(loc: loc, compact: spec.compactHeader),
            Expanded(child: spec.scrollBody ? scrollBody : staticBody),
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
        scrollBody: true,
        horizontalPad: 11,
        topPad: 8,
        bottomPad: 8,
        itemGap: 5,
        sectionGap: 6,
      );
    }
    if (height < 840) {
      return const _DrawerViewportSpec(
        compactHeader: false,
        compactTiles: false,
        scrollBody: true,
        horizontalPad: 12,
        topPad: 10,
        bottomPad: 10,
        itemGap: 6,
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

// DRAWER HEADER

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.loc, required this.compact});
  final AppLocalizations loc;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        topPad + (compact ? 8 : 10),
        12,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.only(
          topRight: ThemeSkeleton.shared.radius(24),
        ),
      ),
      child: _HeaderContent(loc: loc, compact: compact, lowEffects: lowEffects),
    );
  }
}

class _HeaderContent extends ConsumerWidget {
  const _HeaderContent({
    required this.loc,
    required this.compact,
    required this.lowEffects,
  });

  final AppLocalizations loc;
  final bool compact;
  final bool lowEffects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      firebaseUser = null;
    }
    final fallbackName = (firebaseUser?.displayName?.trim().isNotEmpty ?? false)
        ? firebaseUser!.displayName!.trim()
        : loc.guest;
    final fallbackEmail = (firebaseUser?.email ?? '').trim();
    final fallbackImage = (firebaseUser?.photoURL ?? '').trim();

    final profileData = ref.watch(
      userProfileProvider.select((async) => async.valueOrNull),
    );
    final name = ((profileData?['name'] as String?) ?? '').trim().isNotEmpty
        ? (profileData!['name'] as String).trim()
        : fallbackName;
    final email = ((profileData?['email'] as String?) ?? '').trim().isNotEmpty
        ? (profileData!['email'] as String).trim()
        : fallbackEmail;
    final imageUrl =
        ((profileData?['image'] as String?) ?? '').trim().isNotEmpty
        ? (profileData!['image'] as String).trim()
        : fallbackImage;
    final isPremium = ref.watch(isPremiumStateProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatar = compact ? 52.0 : 58.0;
    final iconSize = compact ? 24.0 : 26.0;
    final cardHeight = compact ? 108.0 : 122.0;
    final textColorPrimary = context.colors.textPrimary;
    final textColorSecondary = context.colors.textSecondary;

    final brand = context.rules.drawerBrandColor;
    final surface = context.colors.surface;
    final premiumStart = context.colors.goldStart;
    final premiumMid = context.colors.goldMid;
    final premiumGlow = context.colors.goldGlow;
    const premiumLabelColor = Color(0xFF211500);
    final proAccent = context.colors.proBlue;

    final cardStart = Color.alphaBlend(
      brand.withValues(alpha: isDark ? 0.35 : 0.25),
      surface,
    );
    final cardMid = Color.alphaBlend(
      brand.withValues(alpha: isDark ? 0.45 : 0.35),
      surface,
    );
    final cardEnd = Color.alphaBlend(
      brand.withValues(alpha: isDark ? 0.40 : 0.30),
      surface,
    );

    final waveColor = context.rules.themeWaveColor;

    return SizedBox(
      key: const Key('app_drawer_header_card'),
      height: cardHeight,
      child: ClipRRect(
        borderRadius: ThemeSkeleton.shared.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cardStart, cardMid, cardEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -24,
              left: 40,
              bottom: -80,
              child: Container(
                height: compact ? 138 : 154,
                decoration: BoxDecoration(
                  color: waveColor,
                  borderRadius: ThemeSkeleton.shared.circular(140),
                ),
              ),
            ),
            if (!lowEffects)
              Positioned(
                top: compact ? 14 : 16,
                right: compact ? 78 : 88,
                child: _HeaderDot(opacity: 0.30, size: compact ? 4 : 5),
              ),
            if (!lowEffects)
              Positioned(
                top: compact ? 26 : 28,
                right: compact ? 112 : 124,
                child: _HeaderDot(opacity: 0.36, size: compact ? 3 : 4),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 16,
                compact ? 12 : 14,
                compact ? 14 : 16,
                compact ? 12 : 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        key: const Key('app_drawer_header_avatar'),
                        width: avatar,
                        height: avatar,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 2.4,
                          ),
                          boxShadow: lowEffects
                              ? const <BoxShadow>[]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.13),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: imageUrl.isNotEmpty
                            ? CircularCachedImage(
                                imageUrl: imageUrl,
                                radius: avatar / 2,
                              )
                            : Icon(
                                Icons.person,
                                color: textColorSecondary,
                                size: iconSize,
                              ),
                      ),
                      if (isPremium)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [premiumStart, premiumMid],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.96),
                                width: 1.4,
                              ),
                              boxShadow: lowEffects
                                  ? const <BoxShadow>[]
                                  : [
                                      BoxShadow(
                                        color: premiumGlow.withValues(
                                          alpha: 0.55,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: compact ? 10 : 12),
                  Expanded(
                    child: Padding(
                      padding: ThemeSkeleton.shared.insetsOnly(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: textColorPrimary,
                              fontSize: compact ? 15.5 : 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              height: 1.05,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email.isNotEmpty) ...[
                            SizedBox(height: compact ? 3 : 4),
                            Text(
                              email,
                              style: TextStyle(
                                color: textColorSecondary,
                                fontSize: compact ? 12 : 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (isPremium) ...[
                            SizedBox(height: compact ? 7 : 8),
                            Container(
                              key: const Key('app_drawer_header_premium_badge'),
                              padding: ThemeSkeleton.shared.insetsSymmetric(
                                horizontal: compact ? 8 : 10,
                                vertical: compact ? 3 : 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [premiumStart, premiumMid],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: ThemeSkeleton.shared.circular(24),
                                border: Border.all(
                                  color: premiumMid.withValues(alpha: 0.45),
                                ),
                                boxShadow: lowEffects
                                    ? const <BoxShadow>[]
                                    : [
                                        BoxShadow(
                                          color: premiumGlow.withValues(
                                            alpha: 0.66,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: compact ? 14 : 15,
                                    height: compact ? 14 : 15,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.star_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: ThemeSkeleton.size6),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: compact ? 108 : 132,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        loc.premiumMemberBadge.toUpperCase(),
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          color: premiumLabelColor,
                                          fontSize: compact ? 9.6 : 10.2,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _navigateFromDrawer(
                        context,
                        route: AppPaths.settings,
                        selected: _isSelectedDrawerRoute(
                          _currentDrawerLocation(context),
                          AppPaths.settings,
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: Ink(
                            key: const Key('app_drawer_header_settings_button'),
                            width: compact ? 34 : 38,
                            height: compact ? 34 : 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  proAccent.withValues(alpha: 0.92),
                                  Color.alphaBlend(
                                    Theme.of(context).colorScheme.shadow
                                        .withValues(alpha: 0.28),
                                    proAccent,
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.85),
                                width: 1.2,
                              ),
                              boxShadow: lowEffects
                                  ? const <BoxShadow>[]
                                  : [
                                      BoxShadow(
                                        color: proAccent.withValues(
                                          alpha: 0.34,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              size: compact ? 18 : 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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

class _HeaderDot extends StatelessWidget {
  const _HeaderDot({required this.opacity, required this.size});

  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

// NAV TILE

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.selected,
    required this.accent,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String route;
  final bool selected;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _navigateFromDrawer(context, route: route, selected: selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: compact ? 48 : 52,
          padding: ThemeSkeleton.shared.insetsSymmetric(
            horizontal: compact ? 16 : 20,
          ),
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
// BRANDING
// ─────────────────────────────────────────────
class _Branding extends StatelessWidget {
  const _Branding({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appNameColor = context.colors.textPrimary;
    final appVersionColor = context.colors.textSecondary;

    final cardHeight = compact ? 124.0 : 138.0;
    final iconSize = compact ? 42.0 : 48.0;

    final brand = context.rules.drawerBrandColor;
    final surface = context.colors.surface;

    final footerStart = Color.alphaBlend(
      brand.withValues(alpha: isDark ? 0.28 : 0.18),
      surface,
    );
    final footerMid = Color.alphaBlend(
      brand.withValues(alpha: isDark ? 0.42 : 0.28),
      surface,
    );
    final footerEnd = Color.alphaBlend(
      brand.withValues(alpha: isDark ? 0.36 : 0.24),
      surface,
    );

    final footerWave = context.rules.themeWaveColor;

    return Padding(
      padding: ThemeSkeleton.shared.insetsSymmetric(vertical: compact ? 6 : 8),
      child: SizedBox(
        height: cardHeight,
        child: ClipRRect(
          borderRadius: ThemeSkeleton.shared.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [footerStart, footerMid, footerEnd],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 40,
                right: -26,
                top: -84,
                child: Container(
                  height: compact ? 138 : 154,
                  decoration: BoxDecoration(
                    color: footerWave,
                    borderRadius: ThemeSkeleton.shared.circular(140),
                  ),
                ),
              ),
              if (!lowEffects)
                Positioned(
                  bottom: compact ? 20 : 24,
                  right: compact ? 36 : 44,
                  child: _HeaderDot(opacity: 0.32, size: compact ? 4 : 5),
                ),
              if (!lowEffects)
                Positioned(
                  bottom: compact ? 30 : 34,
                  right: compact ? 64 : 74,
                  child: _HeaderDot(opacity: 0.24, size: compact ? 3 : 4),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  compact ? 10 : 12,
                  compact ? 12 : 14,
                  compact ? 10 : 12,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: compact ? 1.8 : 2.1,
                          ),
                          boxShadow: lowEffects
                              ? const <BoxShadow>[]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/play_store_512-app.png',
                            width: iconSize,
                            height: iconSize,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
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
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: appNameColor,
                          fontSize: compact ? 12.4 : 13.4,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.35,
                          shadows: lowEffects
                              ? const <Shadow>[]
                              : [
                                  Shadow(
                                    color: appNameColor.withValues(alpha: 0.30),
                                    blurRadius: 4,
                                  ),
                                ],
                        ),
                      ),
                      SizedBox(height: compact ? 1.5 : 2),
                      Text(
                        'Version 1.0.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: appVersionColor,
                          fontSize: compact ? 9.2 : 9.7,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
