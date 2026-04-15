// lib/widgets/bottom_nav_bar.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  PREMIUM ANDROID-NATIVE BOTTOM NAV                       ║
// ║  • Material 3 NavigationBar semantics                    ║
// ║  • Pill indicator with spring physics                    ║
// ║  • Adaptive icon tinting (no broken assets)              ║
// ║  • Full gesture-nav / 3-button inset awareness           ║
// ║  • Bangladesh / Dark / Light / System theme-aware        ║
// ║  • Zero jank: no per-frame repaints, O(n) build          ║
// ╚══════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import '../../core/theme/theme_skeleton.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/theme.dart' show AppThemeRulesExtension;
import '../../core/config/performance_config.dart';
import 'platform_surface_treatment.dart';
import '../providers/tab_providers.dart';
import 'premium_shell_palette.dart';

final Expando<_ThemeColors> _themeColorsCache = Expando<_ThemeColors>(
  'bottom_nav_theme_colors',
);

// ─────────────────────────────────────────────────────────────
// DESIGN TOKENS  (local, self-contained)
// ─────────────────────────────────────────────────────────────
class _NT {
  // Heights
  static const double barHeight = 84.0; // content area
  static const double indicatorH = 48.0; // pill height
  static const double indicatorWMin = 64.0; // collapsed pill (icon only)
  static const double indicatorWMax = 90.0; // expanded pill
  static const double iconSize = 32.0;
  static const double labelSize = 10.5;

  // Radii
  static const double indicatorRadius = 18.0;

  // Durations
  static const Duration spring = Duration(milliseconds: 220);
  static const Duration pressDur = Duration(milliseconds: 95);
  static const Duration releaseDur = Duration(milliseconds: 180);

  // Curves
  static const Curve springCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = _SpringCurve();

  // Elevation / shadow
}

/// Custom spring curve that overshoots slightly — authentic Android feel.
class _SpringCurve extends Curve {
  const _SpringCurve();
  @override
  double transformInternal(double t) {
    // Critically damped spring with light overshoot
    const double c = 0.6;
    return 1 -
        (1 - t) * (1 - t) * ((c + 1) * (1 - t) - c) * -1 +
        0.04 * (1 - t) * t * (1 - t);
  }
}

// ─────────────────────────────────────────────────────────────
// THEME RESOLVER  (single source of truth)
// ─────────────────────────────────────────────────────────────
class _ThemeColors {
  _ThemeColors._({
    required this.surface,
    required this.surfaceTint,
    required this.topBorder,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.indicator,
    required this.indicatorSplash,
    required this.shadow,
    required this.themeWave,
    required this.blur,
  });

  factory _ThemeColors.fromTheme(ThemeData theme) {
    final cached = _themeColorsCache[theme];
    if (cached != null) {
      return cached;
    }

    final rules = theme.extension<AppThemeRulesExtension>();
    if (rules == null) {
      // Robust fallback to ColorScheme properties if the extension is missing
      final cs = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;

      final fallback = _ThemeColors._(
        surface: cs.surface,
        surfaceTint: cs.surfaceTint.withValues(alpha: 0.05),
        topBorder: cs.outlineVariant.withValues(alpha: 0.4),
        activeIcon: cs.primary,
        inactiveIcon: cs.onSurfaceVariant.withValues(alpha: 0.8),
        activeLabel: cs.primary,
        inactiveLabel: cs.onSurfaceVariant.withValues(alpha: 0.8),
        indicator: cs.primaryContainer.withValues(alpha: 0.4),
        indicatorSplash: cs.primaryContainer.withValues(alpha: 0.2),
        shadow: isDark ? const Color(0x80000000) : const Color(0x1F000000),
        themeWave: cs.primary.withValues(alpha: 0.2),
        blur: false,
      );
      _themeColorsCache[theme] = fallback;
      return fallback;
    }

    final resolved = _ThemeColors._(
      surface: rules.navSurface,
      surfaceTint: rules.navSurfaceTint,
      topBorder: rules.navTopBorder,
      activeIcon: rules.navActiveIcon,
      inactiveIcon: rules.navInactiveIcon,
      activeLabel: rules.navActiveLabel,
      inactiveLabel: rules.navInactiveLabel,
      indicator: rules.navIndicator,
      indicatorSplash: rules.navIndicatorSplash,
      shadow: rules.navShadow,
      themeWave: rules.themeWaveColor,
      blur: rules.navBlurEnabled,
    );
    _themeColorsCache[theme] = resolved;
    return resolved;
  }

  final Color surface;
  final Color surfaceTint;
  final Color topBorder;
  final Color activeIcon;
  final Color inactiveIcon;
  final Color activeLabel;
  final Color inactiveLabel;
  final Color indicator;
  final Color indicatorSplash;
  final Color shadow;
  final Color themeWave;
  final bool blur;
}

// ─────────────────────────────────────────────────────────────
// NAV ITEM DATA
// ─────────────────────────────────────────────────────────────
class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.assetPath,
  });

  final String Function(AppLocalizations) label;
  final IconData icon;
  final IconData selectedIcon;
  final String assetPath;
}

const List<_NavItemData> _kNavItems = [
  _NavItemData(
    label: _labelHome,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    assetPath: 'assets/images/home.png',
  ),
  _NavItemData(
    label: _labelNewspapers,
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
    assetPath: 'assets/images/news.png',
  ),
  _NavItemData(
    label: _labelSearch,
    icon: Icons.search_rounded,
    selectedIcon: Icons.manage_search_rounded,
    assetPath: 'assets/images/search.png',
  ),
  _NavItemData(
    label: _labelMagazines,
    icon: Icons.bookmark_border_rounded,
    selectedIcon: Icons.bookmark_rounded,
    assetPath: 'assets/images/magazine.png',
  ),
  _NavItemData(
    label: _labelSettings,
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune_rounded,
    assetPath: 'assets/images/settings.png',
  ),
];

String _labelHome(AppLocalizations l) => l.home;
String _labelNewspapers(AppLocalizations l) => l.newspapers;
String _labelSearch(AppLocalizations l) => l.search;
String _labelMagazines(AppLocalizations l) => l.magazines;
String _labelSettings(AppLocalizations l) => l.settings;

// ─────────────────────────────────────────────────────────────
// ROOT WIDGET
// ─────────────────────────────────────────────────────────────
class BottomNavBar extends ConsumerStatefulWidget {
  const BottomNavBar({super.key, this.navigationShell});
  final StatefulNavigationShell? navigationShell;

  @override
  ConsumerState<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends ConsumerState<BottomNavBar> {
  DateTime? _lastTapAt;
  int? _lastTappedIndex;
  int? _previewSelectedIndex;
  bool _syncScheduled = false;
  late final List<ValueNotifier<bool>> _previewSelectionNotifiers =
      List<ValueNotifier<bool>>.generate(
        _kNavItems.length,
        (_) => ValueNotifier<bool>(false),
      );
  static const Duration _tapDebounce = Duration(milliseconds: 80);
  static const Duration _shellCatchUpGrace = Duration(milliseconds: 700);

  void _setPreviewSelection(int? index) {
    final previous = _previewSelectedIndex;
    if (previous == index) return;

    if (previous != null) {
      _previewSelectionNotifiers[previous].value = false;
    }

    _previewSelectedIndex = index;
    if (index != null) {
      _previewSelectionNotifiers[index].value = true;
    }
  }

  void _onItemPreview(int index) {
    if (_previewSelectedIndex == index) return;
    HapticFeedback.selectionClick();
    _setPreviewSelection(index);
  }

  void _clearItemPreview([int? index]) {
    if (_previewSelectedIndex == null) return;
    if (index != null && _previewSelectedIndex != index) return;
    _setPreviewSelection(null);
  }

  void _onItemTapped(BuildContext context, int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigationShell = widget.navigationShell;
    if (navigationShell == null) return;

    final now = DateTime.now();
    if (_lastTapAt != null &&
        _lastTappedIndex == index &&
        now.difference(_lastTapAt!) < _tapDebounce) {
      _clearItemPreview(index);
      return;
    }
    _lastTapAt = now;
    _lastTappedIndex = index;

    ref.read(tabProvider.notifier).setTab(index);
    _clearItemPreview(index);

    // Drawer-launched subpages should not linger in preserved branch stacks.
    navigationShell.goBranch(index, initialLocation: true);
  }

  @override
  void dispose() {
    for (final notifier in _previewSelectionNotifiers) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shellIndex = widget.navigationShell?.currentIndex ?? 0;
    final selectedIndex = ref.watch(currentTabIndexProvider);
    final lastTapAt = _lastTapAt;
    final waitingForTappedBranch =
        _lastTappedIndex == selectedIndex && selectedIndex != shellIndex;
    final shellStillCatchingUp =
        waitingForTappedBranch &&
        lastTapAt != null &&
        DateTime.now().difference(lastTapAt) < _shellCatchUpGrace;

    if (selectedIndex == shellIndex && _lastTappedIndex == shellIndex) {
      _lastTappedIndex = null;
      _lastTapAt = null;
    }

    // Direct sync if providers fall out of step with the shell (e.g. external link)
    if (selectedIndex != shellIndex &&
        !_syncScheduled &&
        !shellStillCatchingUp) {
      _syncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScheduled = false;
        if (!mounted) return;
        final current = ref.read(currentTabIndexProvider);
        final latestShellIndex = widget.navigationShell?.currentIndex ?? 0;
        if (current != latestShellIndex) {
          ref.read(tabProvider.notifier).setTab(latestShellIndex);
        }
      });
    }

    final theme = Theme.of(context);
    final tc = _ThemeColors.fromTheme(theme);
    final perf = PerformanceConfig.of(context);
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final bool lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    final bool lowMotion =
        perf.reduceMotion ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    // Android gesture-nav / 3-button inset
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final rules = Theme.of(context).extension<AppThemeRulesExtension>()!;
    final glowColor = rules.accentGlowColor;

    return _NavBarSurface(
      tc: tc,
      bottomInset: bottomInset,
      lowEffects: lowEffects,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_kNavItems.length, (i) {
          return Expanded(
            child: RepaintBoundary(
              child: ValueListenableBuilder<bool>(
                valueListenable: _previewSelectionNotifiers[i],
                builder: (context, isPreviewSelected, _) {
                  return _NavTile(
                    data: _kNavItems[i],
                    label: _kNavItems[i].label(AppLocalizations.of(context)),
                    isSelected: isPreviewSelected || i == selectedIndex,
                    tc: tc,
                    glowColor: glowColor,
                    reduceMotion: lowMotion,
                    reduceEffects: lowEffects || preferMaterialChrome,
                    onTapPreview: () => _onItemPreview(i),
                    onTapCancelPreview: () => _clearItemPreview(i),
                    onTapCommit: () => _onItemTapped(context, i),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SURFACE  — blur + border + tint + shadow
// ─────────────────────────────────────────────────────────────
class _NavBarSurface extends StatelessWidget {
  const _NavBarSurface({
    required this.tc,
    required this.bottomInset,
    required this.lowEffects,
    required this.child,
  });

  final _ThemeColors tc;
  final double bottomInset;
  final bool lowEffects;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellPalette = theme.extension<PremiumShellPalette>()!;
    final content = SafeArea(
      top: false,
      child: SizedBox(height: _NT.barHeight, child: child),
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: ThemeSkeleton.shared.radius(28),
          topRight: ThemeSkeleton.shared.radius(28),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: shellPalette.borderColor,
                width: lowEffects ? 0.6 : 0.8,
              ),
            ),
            boxShadow: const <BoxShadow>[],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: shellPalette.footerGradient,
                  ),
                ),
              ),
              Positioned(
                left: 44,
                right: -28,
                top: -88,
                child: IgnorePointer(
                  child: Container(
                    height: 152,
                    decoration: BoxDecoration(
                      color: shellPalette.waveColor,
                      borderRadius: ThemeSkeleton.shared.circular(152),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: shellPalette.glossGradient,
                    ),
                  ),
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAV TILE  — pill indicator + icon + label
// ─────────────────────────────────────────────────────────────
class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.data,
    required this.label,
    required this.isSelected,
    required this.tc,
    required this.glowColor,
    required this.reduceMotion,
    required this.reduceEffects,
    required this.onTapPreview,
    required this.onTapCancelPreview,
    required this.onTapCommit,
  });

  final _NavItemData data;
  final String label;
  final bool isSelected;
  final _ThemeColors tc;
  final Color glowColor;
  final bool reduceMotion;
  final bool reduceEffects;
  final VoidCallback onTapPreview;
  final VoidCallback onTapCancelPreview;
  final VoidCallback onTapCommit;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Pill width
  late final Animation<double> _pillW;
  // Indicator opacity
  late final Animation<double> _pillOpacity;
  // Label opacity
  late final Animation<double> _labelOpacity;
  // Vertical icon nudge
  late final Animation<double> _iconY;
  late TextStyle _selectedLabelStyle;
  late TextStyle _unselectedLabelStyle;
  BoxShadow? _pillGlowShadow;

  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.reduceMotion
          ? const Duration(milliseconds: 1)
          : _NT.spring,
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _buildAnimations();
    _refreshVisualCaches();
  }

  void _buildAnimations() {
    _pillW = Tween<double>(
      begin: _NT.indicatorWMin,
      end: _NT.indicatorWMax,
    ).animate(CurvedAnimation(parent: _ctrl, curve: _NT.springCurve));

    _pillOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _iconY = Tween<double>(
      begin: 0.0,
      end: -1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: _NT.springCurve));

    _labelOpacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _refreshVisualCaches() {
    _selectedLabelStyle = TextStyle(
      fontSize: _NT.labelSize,
      fontWeight: FontWeight.w700,
      color: widget.tc.activeLabel,
      letterSpacing: 0.1,
      height: 1.0,
      shadows: widget.reduceEffects
          ? null
          : <Shadow>[
              Shadow(
                color: widget.glowColor.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
    );
    _unselectedLabelStyle = TextStyle(
      fontSize: _NT.labelSize,
      fontWeight: FontWeight.w500,
      color: widget.tc.inactiveLabel,
      letterSpacing: 0.0,
      height: 1.0,
    );
    _pillGlowShadow = widget.reduceEffects
        ? null
        : BoxShadow(
            color: widget.glowColor.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
          );
  }

  @override
  void didUpdateWidget(_NavTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      _ctrl.duration = widget.reduceMotion
          ? const Duration(milliseconds: 1)
          : _NT.spring;
      if (widget.reduceMotion && _pressing) {
        _pressing = false;
      }
    }
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.reduceMotion) {
        _ctrl.value = widget.isSelected ? 1.0 : 0.0;
      } else {
        if (widget.isSelected) {
          _ctrl.animateTo(1.0, curve: _NT.springCurve);
        } else {
          _ctrl.animateTo(0.0, curve: _NT.springCurve);
        }
      }
    }
    if (widget.tc != oldWidget.tc ||
        widget.glowColor != oldWidget.glowColor ||
        widget.reduceEffects != oldWidget.reduceEffects) {
      _refreshVisualCaches();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    widget.onTapPreview();
    if (widget.reduceMotion) return;
    setState(() => _pressing = true);
  }

  void _onTap() {
    if (!widget.reduceMotion) {
      setState(() => _pressing = false);
    }
    widget.onTapCommit();
  }

  void _onTapCancel() {
    widget.onTapCancelPreview();
    if (widget.reduceMotion) return;
    setState(() => _pressing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTap: _onTap,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: widget.reduceMotion ? 1.0 : (_pressing ? 0.88 : 1.0),
        duration: widget.reduceMotion
            ? Duration.zero
            : (_pressing ? _NT.pressDur : _NT.releaseDur),
        curve: widget.reduceMotion
            ? Curves.linear
            : (_pressing ? Curves.easeIn : _NT.bounceCurve),
        child: SizedBox(
          height: _NT.barHeight,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── INDICATOR PILL + ICON ──────────────────────────
        SizedBox(
          height: _NT.indicatorH + 4, // slight buffer
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pill background with theme-aware glow
              Opacity(
                opacity: _pillOpacity.value,
                child: Container(
                  width: _pillW.value,
                  height: _NT.indicatorH,
                  decoration: BoxDecoration(
                    color: widget.tc.indicator,
                    borderRadius: ThemeSkeleton.shared.circular(
                      _NT.indicatorRadius,
                    ),
                    boxShadow: _pillGlowShadow == null
                        ? const <BoxShadow>[]
                        : <BoxShadow>[_pillGlowShadow!],
                  ),
                ),
              ),

              // Icon with subtle glow
              Transform.translate(
                offset: Offset(0, _iconY.value),
                child: _NavIcon(
                  data: widget.data,
                  isSelected: widget.isSelected,
                  activeColor: widget.tc.activeIcon,
                  inactiveColor: widget.tc.inactiveIcon,
                  glowColor: widget.glowColor,
                  reduceEffects: widget.reduceEffects,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: ThemeSkeleton.size2),

        // ── LABEL ──────────────────────────────────────────
        Opacity(
          opacity: _labelOpacity.value,
          child: Text(
            widget.label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: widget.isSelected
                ? _selectedLabelStyle
                : _unselectedLabelStyle,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAV ICON  — cross-fades outlined ↔ filled on selection
// Uses asset image with colorFilter, falls back to Icon widget.
// ─────────────────────────────────────────────────────────────
class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.data,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.glowColor,
    required this.reduceEffects,
  });

  final _NavItemData data;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final Color glowColor;
  final bool reduceEffects;

  @override
  Widget build(BuildContext context) {
    final bool hasGlow = !reduceEffects && isSelected;
    final IconData fallbackIcon = isSelected ? data.selectedIcon : data.icon;
    final Color fallbackColor = isSelected ? activeColor : inactiveColor;

    return Container(
      width: _NT.iconSize + 8,
      height: _NT.iconSize + 8,
      decoration: hasGlow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: Center(
        child: _buildIcon(
          icon: fallbackIcon,
          path: data.assetPath,
          color: fallbackColor,
        ),
      ),
    );
  }

  Widget _buildIcon({
    required IconData icon,
    required String path,
    required Color color,
  }) {
    return Image.asset(
      path,
      width: _NT.iconSize,
      height: _NT.iconSize,
      fit: BoxFit.contain,
      // No tint for detailed images
      errorBuilder: (_, _, _) => Icon(icon, size: _NT.iconSize, color: color),
    );
  }
}
