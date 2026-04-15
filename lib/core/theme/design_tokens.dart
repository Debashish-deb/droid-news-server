import 'package:flutter/material.dart';

// App-wide colors (Unified Design System)
class AppColors {
  AppColors._();

  static const Color darkBackground = Color(0xFF171B1D);
  static const Color darkSurface = Color(0xFF202528);
  static const Color darkSecondary = Color(0xFF2B3033);
  static const Color darkTertiary = Color(0xFF3C4549);

  static const Color dashboardRed = Color(0xFFFF5A5F);

  static const Color gold = Color(0xFFFFD700);
  static const Color brandBlueLight = Color(0xFF007AFF);
  static const Color brandBlueDark = Color(0xFF0A84FF);

  // Onboarding Slide Accents
  static const Color slideBlue = Color(0xFF2563EB);
  static const Color slideGreen = Color(0xFF059669);
  static const Color slideRed = Color(0xFFDC2626);
  static const Color slideBlueDark = Color(0xFF3B82F6);
  static const Color slideGreenDark = Color(0xFF10B981);
  static const Color slideRedDark = Color(0xFFF42A41);
}

// App-wide spacing scale
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double xxxxl = 40.0;

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
  static const EdgeInsets horizontalXxl = EdgeInsets.symmetric(horizontal: xxl);

  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

// Border radius scale
class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
  static const double pill = 999.0;

  static BorderRadius get xsBorder => BorderRadius.circular(xs);
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get xxlBorder => BorderRadius.circular(xxl);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}

// Border width scale
class AppBorders {
  AppBorders._();

  static const double hairline = 0.5;
  static const double thin = 1.0;
  static const double regular = 1.5;
  static const double thick = 2.0;
  static const double extraThick = 3.0;
}

// Elevation scale
class AppElevation {
  AppElevation._();

  static const double none = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 2.0;
  static const double level3 = 4.0;
  static const double level4 = 6.0;
  static const double level5 = 8.0;
}

// Duration scale
class AppDuration {
  AppDuration._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
}

// Android-friendly component sizing
class AppSize {
  AppSize._();

  static const double minTouchTarget = 48.0;
  static const double compactTouchTarget = 44.0;
  static const double buttonHeight = 50.0;
  static const double compactButtonHeight = 44.0;
  static const double inputHeight = 56.0;
  static const double navBarHeight = 80.0;
  static const double navLabelSize = 12.0;
  static const double listTileMinLeadingWidth = 24.0;
  static const double dragHandleWidth = 32.0;
  static const double dragHandleHeight = 4.0;
  static const double fabSize = 56.0;
  static const double iconXs = 16.0;
  static const double iconSm = 18.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 28.0;
}

// App-wide typography styles
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmallSize = 12.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;

  static TextStyle style({
    required double size,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
    double? height,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );
  }

  static TextStyle label(Color color) => style(
    size: 14,
    weight: FontWeight.w600,
    color: color,
    letterSpacing: 0.1,
  );

  static TextStyle body(Color color) => style(
    size: 16,
    weight: FontWeight.w400,
    color: color,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static TextStyle bodySmall(Color color) => style(
    size: 14,
    weight: FontWeight.w400,
    color: color,
    letterSpacing: 0.15,
    height: 1.35,
  );

  static TextStyle title(Color color) =>
      style(size: 22, weight: FontWeight.w600, color: color);
}
