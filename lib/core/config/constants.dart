import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// =============================================================
/// APP SURFACES & ELEVATION (Theme-Aware)
/// =============================================================

class AppSurfaces {
  AppSurfaces._(); 

  /// Base surface (cards, sheets) - Derived from theme
  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  /// Elevated surfaces (dialogs, modals) - Derived from theme
  static Color elevated(BuildContext context, {int level = 1}) {
    final scheme = Theme.of(context).colorScheme;
    switch (level) {
      case 2:
        return scheme.surfaceContainerLow;
      case 3:
        return scheme.surfaceContainer;
      case 4:
        return scheme.surfaceContainerHigh;
      default:
        return scheme.surface;
    }
  }

  /// Separator color - Derived from theme
  static Color divider(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }
}

/// =============================================================
/// MATERIAL GLASSMORPHISM CONSTANTS
/// =============================================================

class AppGlass {
  AppGlass._(); 

  /// Background tint for glass surfaces
  static Color background(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.surface.withValues(alpha: 0.7);
  }

  /// Reusable glass container (Respects reduces motion/effects settings)
  static Widget glass({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    // Check if reduce motion/effects is enabled via MediaQuery or AppPerformance
    final bool disableBlur = MediaQuery.of(context).disableAnimations || AppPerformance.reduceEffects;
    
    final blur = disableBlur ? 0.0 : AppPerformance.glassBlurSigma;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: background(context),
            border: Border.all(color: AppSurfaces.divider(context), width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// =============================================================
/// MATERIAL 3 MOTION CURVES
/// =============================================================

class AppMotion {
  AppMotion._(); 

  /// Standardized Material 3 Easing
  static const Curve standard = Curves.easeInOutCubicEmphasized;

  /// Used for page transitions & modals (Standard M3)
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Short, crisp animation (Extra short)
  static const Duration fast = Duration(milliseconds: 200);

  /// Default M3 motion duration (Medium 1)
  static const Duration normal = Duration(milliseconds: 300);

  /// Long duration for complex transitions
  static const Duration slow = Duration(milliseconds: 500);
}

/// =============================================================
/// PERFORMANCE TUNING (Respects System Settings)
/// =============================================================
class AppPerformance {
  AppPerformance._();

  /// Reduce animations and expensive visual effects by default.
  static const bool reduceMotion = false; // Let MediaQuery drive this
  static const bool reduceEffects = false;

  /// Shorter animations to reduce jank.
  static const Duration animationDuration = Duration(milliseconds: 180);

  /// Standard M3 blur radius.
  static const double glassBlurSigma = 8.0;
}

/// =============================================================
/// PLATFORM-ADAPTIVE ICONS (Rounded Variants)
/// =============================================================

class AdaptiveIcons {
  AdaptiveIcons._(); 

  static IconData settings() => Icons.settings_rounded;

  static IconData share() => Icons.share_rounded;

  static IconData favorite({bool filled = false}) {
    return filled ? Icons.favorite_rounded : Icons.favorite_border_rounded;
  }

  static IconData back() => Icons.arrow_back_rounded;
}

/// =============================================================
/// MATERIAL ↔ CUPERTINO THEME BRIDGE
/// =============================================================

class AppThemeBridge {
  AppThemeBridge._(); 

  /// Material Theme (Optimized for Android)
  static ThemeData materialTheme({
    required Brightness brightness,
    required Color primaryColor,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,

      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B0B14) : const Color(0xFFF8F9FF),

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Cupertino Theme (Minimal fallback)
  static CupertinoThemeData cupertinoTheme({
    required Brightness brightness,
    required Color primaryColor,
  }) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor:
          brightness == Brightness.dark
              ? const Color(0xFF000000)
              : const Color(0xFFFFFFFF),
    );
  }
}
