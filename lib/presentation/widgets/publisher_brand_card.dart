import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/enums/theme_mode.dart';
import '../../core/theme/theme.dart' show AppGradients;
import '../../core/theme/theme_skeleton.dart';
import 'publisher_brand_palette.dart';

PublisherBrandPalette _publisherPaletteOf(ThemeData theme) {
  final extension = theme.extension<PublisherBrandPalette>();
  if (extension != null) return extension;

  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  return PublisherBrandPalette(
    surfaceTop: isDark ? const Color(0xFF20262A) : scheme.surface,
    surfaceBottom: isDark
        ? const Color(0xFF293035)
        : scheme.surfaceContainerHighest,
    surfaceBorder: isDark ? const Color(0xFF59636B) : scheme.outlineVariant,
    accent: scheme.primary,
    favoriteGlow: scheme.primary,
    ambientGlow: scheme.primary,
    shadow: isDark ? Colors.black : Colors.black.withValues(alpha: 0.18),
  );
}

/// Reusable publisher surface card used by both newspaper and magazine views.
///
/// Centralizing this widget keeps rendering behavior consistent and prevents
/// drift between two nearly-identical implementations.
class PublisherBrandCard extends StatelessWidget {
  const PublisherBrandCard({
    required this.publisherName,
    required this.localLogoPath,
    required this.fallbackText,
    required this.mode,
    required this.highlight,
    required this.isFavorite,
    required this.onTap,
    super.key,
    this.clipLogo = false,
    this.preferFlatSurface = false,
    this.lightweightMode = false,
    this.skeleton = ThemeSkeleton.shared,
  });

  final String publisherName;
  final String? localLogoPath;
  final String fallbackText;
  final AppThemeMode mode;
  final bool highlight;
  final bool isFavorite;
  final VoidCallback onTap;
  final bool clipLogo;
  final bool preferFlatSurface;
  final bool lightweightMode;
  final ThemeSkeleton skeleton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (preferFlatSurface) {
      return _FlatPublisherBrandCard(
        publisherName: publisherName,
        localLogoPath: localLogoPath,
        fallbackText: fallbackText,
        mode: mode,
        isFavorite: isFavorite,
        onTap: onTap,
        clipLogo: clipLogo,
        lightweightMode: lightweightMode,
        skeleton: skeleton,
      );
    }

    if (lightweightMode) {
      return _LightweightPublisherBrandCard(
        publisherName: publisherName,
        fallbackText: fallbackText,
        onTap: onTap,
        skeleton: skeleton,
      );
    }

    final gradientColors = AppGradients.getGradientColors(mode);
    final scheme = theme.colorScheme;
    final publisherPalette = _publisherPaletteOf(theme);
    final isDark = theme.brightness == Brightness.dark;
    final isDesh = mode.name == 'bangladesh';
    final useDarkLogoTreatment = isDark;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final double outerRadius = skeleton.cardRadius;
    final double borderWidth = isDesh
        ? skeleton.borderWidth + 0.2
        : skeleton.borderWidth;
    final Gradient? cardGradient = isDark
        ? null
        : isDesh
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              publisherPalette.surfaceTop.withValues(alpha: 0.96),
              publisherPalette.surfaceBottom.withValues(alpha: 0.98),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: highlight
                ? gradientColors
                : [
                    Colors.white.withValues(alpha: 0.98),
                    scheme.surface.withValues(alpha: 0.96),
                  ],
          );
    final Color wrapperBorderColor = isDesh
        ? Colors.white.withValues(alpha: 0.30)
        : isDark
        ? publisherPalette.accent.withValues(alpha: 0.72)
        : publisherPalette.surfaceBorder.withValues(alpha: 0.35);

    const BoxShadow subtleHalo = BoxShadow(
      color: Color(0x0F7F7F7F),
      blurRadius: 12,
      spreadRadius: 2,
      offset: Offset(0, 6),
    );

    final BoxShadow favouriteHalo = BoxShadow(
      color: publisherPalette.favoriteGlow.withValues(
        alpha: isDesh
            ? 0.28
            : isDark
            ? 0.38
            : 0.45,
      ),
      blurRadius: isDesh
          ? 18
          : isDark
          ? 22
          : 26,
      spreadRadius: isDesh
          ? 2
          : isDark
          ? 3
          : 4,
      offset: const Offset(0, 8),
    );

    final BoxShadow cardShadow = isDark
        ? const BoxShadow(color: Colors.transparent)
        : subtleHalo;
    final Color cardFillColor = isDark
        ? publisherPalette.surfaceTop.withValues(alpha: 0.08)
        : Colors.transparent;

    final Widget logo = _PublisherLogo(
      localLogoPath: localLogoPath,
      fallbackText: fallbackText,
      isAmoled: useDarkLogoTreatment,
      devicePixelRatio: devicePixelRatio,
      clipLogo: clipLogo,
    );

    final Widget cardContent = logo;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AspectRatio(
          aspectRatio: 3 / 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: ThemeSkeleton.shared.circular(outerRadius),
              color: cardFillColor,
              gradient: cardGradient,
              border: Border.all(color: wrapperBorderColor, width: borderWidth),
              boxShadow: <BoxShadow>[isFavorite ? favouriteHalo : cardShadow],
            ),
            child: ClipRRect(
              borderRadius: ThemeSkeleton.shared.circular(outerRadius),
              child: cardContent,
            ),
          ),
        ),
      );
  }
}

class PublisherBrandLoadingCard extends StatelessWidget {
  const PublisherBrandLoadingCard({
    super.key,
    this.skeleton = ThemeSkeleton.shared,
  });

  final ThemeSkeleton skeleton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final publisherPalette = _publisherPaletteOf(theme);
    final isDark = theme.brightness == Brightness.dark;
    final outerRadius = skeleton.cardRadius;
    final innerRadius = skeleton.innerCardRadius;
    final surfaceColor = isDark
        ? publisherPalette.surfaceTop.withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.9);
    final shellTop = isDark
        ? publisherPalette.surfaceTop.withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.98);
    final shellBottom = isDark
        ? publisherPalette.surfaceBottom.withValues(alpha: 0.96)
        : scheme.surface.withValues(alpha: 0.96);
    final borderColor = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.55 : 0.18,
    );
    final accentColor = publisherPalette.accent.withValues(
      alpha: isDark ? 0.18 : 0.1,
    );
    final ghostColor = scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.07);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: ThemeSkeleton.shared.circular(outerRadius),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: ThemeSkeleton.shared.insetsSymmetric(
            horizontal: 4,
            vertical: 2,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: ThemeSkeleton.shared.circular(innerRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [shellTop, shellBottom],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: ThemeSkeleton.shared.circular(innerRadius),
                    gradient: RadialGradient(
                      radius: 0.82,
                      colors: [accentColor, Colors.transparent],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 150,
                    height: 58,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: ThemeSkeleton.shared.circular(22),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: ghostColor,
                          borderRadius: ThemeSkeleton.shared.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: ghostColor,
                          borderRadius: ThemeSkeleton.shared.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _FlatPublisherBrandCard extends StatelessWidget {
  const _FlatPublisherBrandCard({
    required this.publisherName,
    required this.localLogoPath,
    required this.fallbackText,
    required this.mode,
    required this.isFavorite,
    required this.onTap,
    required this.clipLogo,
    required this.lightweightMode,
    required this.skeleton,
  });

  final String publisherName;
  final String? localLogoPath;
  final String fallbackText;
  final AppThemeMode mode;
  final bool isFavorite;
  final VoidCallback onTap;
  final bool clipLogo;
  final bool lightweightMode;
  final ThemeSkeleton skeleton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final publisherPalette = _publisherPaletteOf(theme);
    final isDark = theme.brightness == Brightness.dark;
    final isDesh = mode.name == 'bangladesh';
    final outerRadius = skeleton.cardRadius;
    final surfaceColor = isDark
        ? publisherPalette.surfaceTop.withValues(alpha: 0.08)
        : isDesh
        ? publisherPalette.surfaceBottom.withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.9);
    final gradient = lightweightMode || isDark
        ? null
        : isDesh
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              publisherPalette.surfaceTop.withValues(alpha: 0.96),
              publisherPalette.surfaceBottom.withValues(alpha: 0.98),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.98),
              scheme.surface.withValues(alpha: 0.96),
            ],
          );
    final borderColor = isDesh
        ? Colors.white.withValues(alpha: isFavorite ? 0.42 : 0.26)
        : (isFavorite ? scheme.primary : scheme.outlineVariant).withValues(
            alpha: isFavorite ? 0.46 : (isDark ? 0.78 : 0.18),
          );
    final resolvedBorderColor = isDark
        ? isDesh
              ? borderColor
              : (isFavorite
                        ? publisherPalette.accent
                        : publisherPalette.surfaceBorder)
                    .withValues(alpha: isFavorite ? 0.76 : 0.80)
        : borderColor;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cardDecoration = BoxDecoration(
      color: surfaceColor,
      gradient: gradient,
      borderRadius: ThemeSkeleton.shared.circular(outerRadius),
      border: Border.all(color: resolvedBorderColor),
      boxShadow: lightweightMode || !isFavorite || isDark
          ? const []
          : [
              BoxShadow(
                color: publisherPalette.favoriteGlow.withValues(
                  alpha: isDark ? 0.20 : 0.16,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: cardDecoration,
          child: ClipRRect(
            borderRadius: ThemeSkeleton.shared.circular(outerRadius),
            child: _PublisherLogo(
              localLogoPath: localLogoPath,
              fallbackText: fallbackText,
              isAmoled: isDark,
              devicePixelRatio: devicePixelRatio,
              clipLogo: clipLogo,
            ),
          ),
        ),
      );
  }
}

class _LightweightPublisherBrandCard extends StatelessWidget {
  const _LightweightPublisherBrandCard({
    required this.publisherName,
    required this.fallbackText,
    required this.onTap,
    required this.skeleton,
  });

  final String publisherName;
  final String fallbackText;
  final VoidCallback onTap;
  final ThemeSkeleton skeleton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final publisherPalette = _publisherPaletteOf(theme);
    final name = publisherName.trim().isEmpty ? fallbackText : publisherName;

    return Material(
      color: publisherPalette.surfaceTop.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.08 : 0.72,
      ),
        borderRadius: ThemeSkeleton.shared.circular(skeleton.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: ThemeSkeleton.shared.circular(skeleton.cardRadius),
          child: Padding(
            padding: ThemeSkeleton.shared.insetsSymmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: publisherPalette.accent.withValues(alpha: 0.12),
                    borderRadius: ThemeSkeleton.shared.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    fallbackText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: publisherPalette.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _PublisherLogo extends StatelessWidget {
  const _PublisherLogo({
    required this.localLogoPath,
    required this.fallbackText,
    required this.isAmoled,
    required this.devicePixelRatio,
    required this.clipLogo,
  });

  final String? localLogoPath;
  final String fallbackText;
  final bool isAmoled;
  final double devicePixelRatio;
  final bool clipLogo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const leftPadding = 22.0;
        const rightPadding = 22.0;
        const topPadding = 14.0;
        const bottomPadding = 14.0;
        const logoScale = 1.5;
        final maxLogoWidth = math.max(
          0.0,
          constraints.maxWidth - leftPadding - rightPadding,
        );
        final maxLogoHeight = math.max(
          0.0,
          constraints.maxHeight - topPadding - bottomPadding,
        );
        final logoBoxWidth = math.min(
          constraints.maxWidth * 0.56 * logoScale,
          maxLogoWidth,
        );
        final logoBoxHeight = math.min(
          constraints.maxHeight * 0.50 * logoScale,
          maxLogoHeight,
        );
        final logoCacheWidth = (logoBoxWidth * devicePixelRatio).round();
        final logoCacheHeight = (logoBoxHeight * devicePixelRatio).round();

        return Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              leftPadding,
              topPadding,
              rightPadding,
              bottomPadding,
            ),
            child: Align(
              child: Padding(
                padding: ThemeSkeleton.shared.insetsSymmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: logoBoxWidth,
                  height: logoBoxHeight,
                  child: localLogoPath != null
                      ? _LogoAsset(
                          path: localLogoPath!,
                          isAmoled: isAmoled,
                          cacheWidth: logoCacheWidth,
                          cacheHeight: logoCacheHeight,
                          clipLogo: clipLogo,
                          fallbackText: fallbackText,
                        )
                      : _fallbackAvatar(fallbackText, context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogoAsset extends StatelessWidget {
  const _LogoAsset({
    required this.path,
    required this.isAmoled,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.clipLogo,
    required this.fallbackText,
  });

  final String path;
  final bool isAmoled;
  final int cacheWidth;
  final int cacheHeight;
  final bool clipLogo;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      path,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stackTrace) =>
          _fallbackAvatar(fallbackText, context),
    );
    if (!clipLogo) return image;
    return ClipRRect(
      borderRadius: ThemeSkeleton.shared.circular(16),
      child: image,
    );
  }
}

Widget _fallbackAvatar(String initials, BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: ThemeSkeleton.shared.circular(16),
    ),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
