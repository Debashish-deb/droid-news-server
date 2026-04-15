import 'package:flutter/material.dart';

import '../../widgets/premium_shell_palette.dart';

class SettingsButtonPalette {
  const SettingsButtonPalette({
    required this.foreground,
    required this.decoration,
  });

  final Color foreground;
  final BoxDecoration decoration;
}

SettingsButtonPalette resolveSettingsButtonPalette(
  BuildContext context, {
  required bool active,
  double radius = 14,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  final reduceEffects = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final shellPalette = theme.extension<PremiumShellPalette>()!;
  final inactiveBorderColor = isDark
      ? shellPalette.iconBorder.withValues(alpha: 0.52)
      : cs.outline.withValues(alpha: 0.35);

  final inactiveFill = isDark
      ? cs.surface.withValues(alpha: 0.10)
      : Color.alphaBlend(
          cs.primary.withValues(alpha: 0.04),
          cs.surface.withValues(alpha: 0.98),
        );

  if (!active) {
    return SettingsButtonPalette(
      foreground: cs.onSurface.withValues(alpha: 0.92),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [inactiveFill, inactiveFill]),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: inactiveBorderColor,
          width: isDark ? 1.15 : 0.8,
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
    );
  }

  return SettingsButtonPalette(
    foreground: shellPalette.textColor,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          shellPalette.gradientStart,
          shellPalette.gradientMid,
          shellPalette.gradientEnd,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: shellPalette.iconBorder.withValues(alpha: isDark ? 0.90 : 0.92),
        width: isDark ? 1.45 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: shellPalette.gradientMid.withValues(
            alpha: reduceEffects ? 0.12 : 0.22,
          ),
          blurRadius: reduceEffects ? 10 : 18,
          offset: const Offset(0, 4),
          spreadRadius: 0.5,
        ),
        BoxShadow(
          color: shellPalette.waveColor.withValues(
            alpha: reduceEffects ? 0.05 : 0.12,
          ),
          blurRadius: reduceEffects ? 8 : 16,
          offset: const Offset(0, 2),
        ),
      ],
    ),
  );
}
