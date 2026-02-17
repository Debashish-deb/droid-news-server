

import 'package:flutter/material.dart';

// App-wide colors (Unified Design System)
class AppColors {
  AppColors._();

  // Dark Theme Tokens (Deep Mocha)
  static const Color darkBackground = Color(0xFF3B3636);
  static const Color darkSurface = Color(0xFF454040);
  static const Color darkSecondary = Color(0xFF555050);
  static const Color darkTertiary = Color(0xFF6B6666);
  
  // Brand / Common Colors
  static const Color gold = Color(0xFFFFD700);
  static const Color brandBlueLight = Color(0xFF007AFF);
  static const Color brandBlueDark = Color(0xFF0A84FF);
}

// App-wide spacing scale
///
// Use these instead of hardcoded values for consistent spacing.
// Based on 4px grid system (mobile-optimized)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;

  static const double sm = 8.0;

  static const double md = 12.0;

  static const double lg = 16.0;

  static const double xl = 20.0;

  static const double xxl = 24.0;

  static const double xxxl = 32.0;

  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);

  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

// Border radius scale
///
// Standardized radius values for cards, buttons, and containers.
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;

  static const double md = 12.0;

  static const double lg = 16.0;   // Cards
  
  static const double xl = 28.0;   // Large containers/Dialogs (M3 standard)

  static const double xxl = 32.0;

  static const double circular = 999.0;

  static BorderRadius get circularBorder => BorderRadius.circular(circular);
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get xxlBorder => BorderRadius.circular(xxl);
}

// Border width scale
///
// Standardized border thicknesses for consistency.
class AppBorders {
  AppBorders._();

  static const double hairline = 0.5;

  static const double thin = 1.0;

  static const double regular = 1.5;

  static const double thick = 2.0;

  static const double extraThick = 3.0;
}

// Elevation scale for shadows
///
// Standardized shadow depths for layering.
class AppElevation {
  AppElevation._();

  static const double none = 0.0;
  static const double level1 = 1.0; // Tonal surface 1
  static const double level2 = 3.0; // Tonal surface 2
  static const double level3 = 6.0; // Tonal surface 3
  static const double level4 = 8.0; // Tonal surface 4
  static const double level5 = 12.0; // Tonal surface 5
  
  // Legacy mappings for compatibility
  static const double sm = level1;
  static const double md = level2;
  static const double lg = level3;
  static const double xl = level4;
  static const double xxl = level5;
}

// Icon sizes
///
// Standardized icon dimensions.
class AppIconSize {
  AppIconSize._();

  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 40.0;
  static const double xxl = 48.0;
}

// Common durations for animations
///
// Standardized animation timings.
class AppDuration {
  AppDuration._();

  static const Duration instant = Duration();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 500);
}

// Typography scale (if needed beyond theme)
///
// Additional text size presets.
class AppTextSize {
  AppTextSize._();

  static const double xs = 10.0;
  static const double sm = 12.0;
  static const double md = 14.0;
  static const double lg = 16.0;
  static const double xl = 18.0;
  static const double xxl = 20.0;
  static const double xxxl = 24.0;
  static const double huge = 32.0;
}

// Opacity values
///
// Standardized transparency levels.
class AppOpacity {
  AppOpacity._();

  static const double transparent = 0.0;
  static const double faint = 0.05;
  static const double light = 0.1;
  static const double subtle = 0.15;
  static const double medium = 0.3;
  static const double strong = 0.6;
  static const double opaque = 1.0;
}

// App-wide typography styles
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter'; // Premium Android standard

  static const TextStyle headline1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headline2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
}
