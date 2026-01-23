// lib/core/design_tokens.dart
// ========================================
// DESIGN SYSTEM - SPACING, BORDERS, RADIUS
// ========================================
//
// This file defines the core design tokens for the app.
// Use these constants throughout the app for consistency.

import 'package:flutter/material.dart';

/// App-wide spacing scale
///
/// Use these instead of hardcoded values for consistent spacing.
/// Based on 4px grid system (mobile-optimized)
class AppSpacing {
  AppSpacing._();

  /// 4px - Minimal spacing (icon padding, tight gaps)
  static const double xs = 4.0;

  /// 8px - Small spacing (button padding, list item gaps)
  static const double sm = 8.0;

  /// 12px - Medium-small spacing (card internal padding)
  static const double md = 12.0;

  /// 16px - Medium spacing (default padding, section gaps)
  static const double lg = 16.0;

  /// 20px - Medium-large spacing (card padding, header spacing)
  static const double xl = 20.0;

  /// 24px - Large spacing (screen padding, major sections)
  static const double xxl = 24.0;

  /// 32px - Extra large spacing (hero sections, major dividers)
  static const double xxxl = 32.0;

  /// Edge insets shortcuts for common patterns
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);

  /// Horizontal padding presets
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  /// Vertical padding presets
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius scale
///
/// Standardized radius values for cards, buttons, and containers.
class AppRadius {
  AppRadius._();

  /// 8px - Small radius (buttons, chips, small cards)
  static const double sm = 8.0;

  /// 12px - Medium radius (standard cards, inputs)
  static const double md = 12.0;

  /// 16px - Large radius (feature cards, dialogs)
  static const double lg = 16.0;

  /// 20px - Extra large radius (hero cards, premium features)
  static const double xl = 20.0;

  /// 24px - Maximum radius (special highlights)
  static const double xxl = 24.0;

  /// Circular radius (for avatars, icon containers)
  static const double circular = 999.0;

  /// BorderRadius shortcuts
  static BorderRadius get circularBorder => BorderRadius.circular(circular);
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get xxlBorder => BorderRadius.circular(xxl);
}

/// Border width scale
///
/// Standardized border thicknesses for consistency.
class AppBorders {
  AppBorders._();

  /// 0.5px - Hairline border (subtle dividers)
  static const double hairline = 0.5;

  /// 1.0px - Thin border (default cards, inputs)
  static const double thin = 1.0;

  /// 1.5px - Regular border (emphasized cards)
  static const double regular = 1.5;

  /// 2.0px - Thick border (focus states, important elements)
  static const double thick = 2.0;

  /// 3.0px - Extra thick (premium features, special highlights)
  static const double extraThick = 3.0;
}

/// Elevation scale for shadows
///
/// Standardized shadow depths for layering.
class AppElevation {
  AppElevation._();

  static const double none = 0.0;
  static const double sm = 2.0;
  static const double md = 4.0;
  static const double lg = 8.0;
  static const double xl = 12.0;
  static const double xxl = 16.0;
}

/// Icon sizes
///
/// Standardized icon dimensions.
class AppIconSize {
  AppIconSize._();

  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 40.0;
  static const double xxl = 48.0;
}

/// Common durations for animations
///
/// Standardized animation timings.
class AppDuration {
  AppDuration._();

  static const Duration instant = Duration();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 500);
}

/// Typography scale (if needed beyond theme)
///
/// Additional text size presets.
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

/// Opacity values
///
/// Standardized transparency levels.
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
