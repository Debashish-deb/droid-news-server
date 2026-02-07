import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// =============================================================
/// APP SURFACES & ELEVATION (iOS-style)
/// =============================================================

class AppSurfaces {
  AppSurfaces._(); 

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Base surface (cards, sheets)
  static Color surface(BuildContext context) {
    return _isDark(context)
        ? const Color(0xFF1C1C1E) 
        : const Color(0xFFFFFFFF);
  }

  /// Elevated surfaces (dialogs, modals)
  static Color elevated(BuildContext context, {int level = 1}) {
    if (!_isDark(context)) return surface(context);

    switch (level) {
      case 2:
        return const Color(0xFF2C2C2E);
      case 3:
        return const Color(0xFF3A3A3C);
      case 4:
        return const Color(0xFF48484A);
      default:
        return const Color(0xFF1C1C1E);
    }
  }

  /// Hairline separator color
  static Color divider(BuildContext context) {
    return _isDark(context) ? const Color(0xFF38383A) : const Color(0xFFD1D1D6);
  }
}

/// =============================================================
/// iOS BLUR / GLASS CONSTANTS
/// =============================================================

class AppGlass {
  AppGlass._(); 

  /// Default iOS blur strength
  static const double blurSigma = 20.0;

  /// Background tint for glass surfaces
  static Color background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xAA1C1C1E) : const Color(0xCCFFFFFF);
  }

  /// Reusable glass container
  static Widget glass({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
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
/// CUPERTINO MOTION CURVES (NO MATERIAL BOUNCE)
/// =============================================================

class AppMotion {
  AppMotion._(); 

  /// Standard iOS easing
  static const Curve standard = Curves.easeOutCubic;

  /// Used for page transitions & modals
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Short, crisp animation
  static const Duration fast = Duration(milliseconds: 180);

  /// Default iOS motion duration
  static const Duration normal = Duration(milliseconds: 260);
}

/// =============================================================
/// PERFORMANCE TUNING (BATTERY & LOW-END DEVICES)
/// =============================================================
class AppPerformance {
  AppPerformance._();

  /// Reduce animations and expensive visual effects by default.
  static const bool reduceMotion = true;
  static const bool reduceEffects = true;

  /// Shorter animations to reduce jank and battery usage.
  static const Duration animationDuration = Duration(milliseconds: 180);

  /// Lower blur radius for glass effects when enabled.
  static const double glassBlurSigma = 4.0;
}

/// =============================================================
/// PLATFORM-ADAPTIVE ICONS
/// =============================================================

class AdaptiveIcons {
  AdaptiveIcons._(); 

  static IconData settings() =>
      Platform.isIOS ? CupertinoIcons.settings : Icons.settings_outlined;

  static IconData share() =>
      Platform.isIOS ? CupertinoIcons.share : Icons.share_outlined;

  static IconData favorite({bool filled = false}) {
    if (Platform.isIOS) {
      return filled ? CupertinoIcons.heart_fill : CupertinoIcons.heart;
    }
    return filled ? Icons.favorite : Icons.favorite_border;
  }

  static IconData back() =>
      Platform.isIOS ? CupertinoIcons.back : Icons.arrow_back;
}

/// =============================================================
/// MATERIAL ↔ CUPERTINO THEME BRIDGE
/// =============================================================

class AppThemeBridge {
  AppThemeBridge._(); 

  /// Material Theme (used by Scaffold, lists, etc.)
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
          isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ),

      cardColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),

      dividerColor: isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Cupertino Theme (used by Cupertino widgets)
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
              : const Color(0xFFF2F2F7),
      barBackgroundColor:
          brightness == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : const Color(0xFFFFFFFF),
    );
  }
}
