import 'dart:math' as math;
import '../../core/theme/theme_skeleton.dart';

import 'package:flutter/material.dart';

import '../../core/config/performance_config.dart';
import '../../core/theme/design_tokens.dart';
import 'premium_shell_palette.dart';

enum PremiumHeaderLeading { menu, back, close, none }

class PremiumScreenHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const PremiumScreenHeader({
    required this.title,
    this.subtitle,
    this.leading = PremiumHeaderLeading.back,
    this.leadingIcon,
    this.onLeadingTap,
    this.actions = const <Widget>[],
    this.height = 108,
    this.titleMaxLines = 1,
    super.key,
  });

  final String title;
  final String? subtitle;
  final PremiumHeaderLeading leading;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingTap;
  final List<Widget> actions;
  final double height;
  final int titleMaxLines;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perf = PerformanceConfig.of(context);
    final reduceEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    final isDark = theme.brightness == Brightness.dark;
    final shellPalette =
        theme.extension<PremiumShellPalette>() ?? _fallbackShellPalette(theme);

    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final titleOffset = hasSubtitle ? 12.0 : 18.0;

    final cardHeight = height - 14;

    return RepaintBoundary(
      child: Container(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: ClipRRect(
            borderRadius: ThemeSkeleton.shared.circular(22),
            child: SizedBox(
              height: cardHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: shellPalette.headerGradient,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -24,
                    left: 56,
                    bottom: -72,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: shellPalette.waveColor,
                        borderRadius: ThemeSkeleton.shared.circular(140),
                      ),
                    ),
                  ),
                  if (!reduceEffects)
                    Positioned(
                      top: 14,
                      right: 80,
                      child: _sparkDot(4, Colors.white.withValues(alpha: 0.30)),
                    ),
                  if (!reduceEffects)
                    Positioned(
                      top: 24,
                      right: 108,
                      child: _sparkDot(3, Colors.white.withValues(alpha: 0.24)),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(10, 8 + titleOffset, 8, 8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            _buildLeading(
                              context: context,
                              reduceEffects: reduceEffects,
                              iconColor: shellPalette.textColor,
                              backgroundColor: shellPalette.iconBackground,
                              borderColor: shellPalette.iconBorder,
                            ),
                            const Spacer(),
                            if (actions.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions,
                              )
                            else
                              const SizedBox(width: ThemeSkeleton.size39),
                          ],
                        ),
                        IgnorePointer(
                          child: Padding(
                            padding: ThemeSkeleton.shared.insetsSymmetric(
                              horizontal: math.max(
                                72,
                                56 + (actions.length * 40),
                              ),
                            ),
                            child: _HeaderTitleBlock(
                              title: title,
                              subtitle: subtitle,
                              titleMaxLines: titleMaxLines,
                              textColor: shellPalette.textColor,
                              subtitleColor: shellPalette.subtitleColor,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading({
    required BuildContext context,
    required bool reduceEffects,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    if (leading == PremiumHeaderLeading.none) {
      return const SizedBox(width: ThemeSkeleton.size36);
    }

    final icon =
        leadingIcon ??
        switch (leading) {
          PremiumHeaderLeading.menu => Icons.menu_rounded,
          PremiumHeaderLeading.back => Icons.arrow_back_rounded,
          PremiumHeaderLeading.close => Icons.keyboard_arrow_down_rounded,
          PremiumHeaderLeading.none => Icons.circle,
        };

    return Builder(
      builder: (ctx) {
        void handleTap() {
          if (onLeadingTap != null) {
            onLeadingTap!.call();
            return;
          }
          switch (leading) {
            case PremiumHeaderLeading.menu:
              final scaffold = Scaffold.maybeOf(ctx);
              if (scaffold != null && scaffold.hasDrawer) {
                scaffold.openDrawer();
              } else {
                Navigator.of(ctx).maybePop();
              }
            case PremiumHeaderLeading.back:
            case PremiumHeaderLeading.close:
              Navigator.of(ctx).maybePop();
            case PremiumHeaderLeading.none:
              break;
          }
        }

        final button = PremiumHeaderIconButton(
          icon: icon,
          onPressed: handleTap,
          iconColor: iconColor,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          reduceEffects: reduceEffects,
        );

        return button;
      },
    );
  }

  Widget _sparkDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

PremiumShellPalette _fallbackShellPalette(ThemeData theme) {
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  final base = isDark ? scheme.surfaceContainerHighest : scheme.primary;
  final textColor = isDark ? scheme.onSurface : scheme.onPrimary;

  return PremiumShellPalette(
    gradientStart: scheme.surface,
    gradientMid: scheme.surfaceContainerHighest,
    gradientEnd: scheme.surface,
    waveColor: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.10),
    iconBackground: scheme.surface.withValues(alpha: isDark ? 0.30 : 0.18),
    iconBorder: textColor.withValues(alpha: 0.20),
    textColor: textColor,
    subtitleColor: textColor.withValues(alpha: 0.74),
    glossColor: Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
    borderColor: textColor.withValues(alpha: 0.16),
    headerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base.withValues(alpha: isDark ? 0.92 : 0.98),
        scheme.secondary.withValues(alpha: isDark ? 0.70 : 0.88),
      ],
    ),
    footerGradient: LinearGradient(
      colors: [scheme.surface, scheme.surfaceContainerHighest, scheme.surface],
    ),
    glossGradient: LinearGradient(
      colors: [
        Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
        Colors.transparent,
      ],
    ),
  );
}

class _HeaderTitleBlock extends StatelessWidget {
  const _HeaderTitleBlock({
    required this.title,
    required this.subtitle,
    required this.titleMaxLines,
    required this.textColor,
    required this.subtitleColor,
    required this.isDark,
  });

  final String title;
  final String? subtitle;
  final int titleMaxLines;
  final Color textColor;
  final Color subtitleColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty &&
        (subtitle == null || subtitle!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitle != null && subtitle!.trim().isNotEmpty)
          Container(
            padding: ThemeSkeleton.shared.insetsSymmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: ThemeSkeleton.shared.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.92),
              ),
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 10.2,
                fontWeight: FontWeight.w800,
                color: subtitleColor,
                letterSpacing: 0.75,
              ),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (subtitle != null && subtitle!.trim().isNotEmpty)
          const SizedBox(height: ThemeSkeleton.size5),
        if (title.trim().isNotEmpty)
          DefaultTextStyle(
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: subtitle == null ? 16.2 : 15.2,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.1,
              height: 1.15,
            ),
            child: Text(
              title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class PremiumHeaderIconButton extends StatelessWidget {
  const PremiumHeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.reduceEffects = false,
    this.size = 36,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool reduceEffects;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hitSize = math.max(48.0, size + 10);

    final resolvedIconColor =
        iconColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.92)
            : theme.colorScheme.onSurface.withValues(alpha: 0.9));
    final resolvedBg =
        backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.78));
    final resolvedBorder =
        borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.34)
            : Colors.white.withValues(alpha: 0.92));

    return Tooltip(
      message: tooltip ?? '',
      child: Padding(
        padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 1.5),
        child: SizedBox.square(
          dimension: hitSize,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: Ink(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resolvedBg,
                    border: Border.all(color: resolvedBorder, width: 1.1),
                    boxShadow: reduceEffects
                        ? const <BoxShadow>[]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Icon(icon, size: 18.5, color: resolvedIconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
