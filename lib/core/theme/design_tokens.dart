
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// App-wide colors (Unified Design System)
class AppColors {
  AppColors._();

  // Dark Theme Tokens (Deep Navy / Midnight) - Synced with theme.dart
  static const Color darkBackground = Color(0xFF0B0B14);
  static const Color darkSurface = Color(0xFF13131F);
  static const Color darkSecondary = Color(0xFF1A1A28);
  static const Color darkTertiary = Color(0xFF2A2A3E);
  
  // Brand / Common Colors
  static const Color gold = Color(0xFFFFD700);
  static const Color brandBlueLight = Color(0xFF007AFF);
  static const Color brandBlueDark = Color(0xFF0A84FF);
}

// App-wide spacing scale
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
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;   
  static const double xl = 28.0;   
  static const double circular = 999.0;

  static BorderRadius get circularBorder => BorderRadius.circular(circular);
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get xxlBorder => BorderRadius.circular(32.0);
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
  static const double level2 = 3.0; 
  static const double level3 = 6.0; 
  static const double level4 = 8.0; 
  static const double level5 = 12.0; 
}

// Duration scale
class AppDuration {
  AppDuration._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

// App-wide typography styles
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter'; 

  static TextStyle get headline1 => GoogleFonts.getFont(
    fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static TextStyle get headline2 => GoogleFonts.getFont(
    fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static TextStyle get body1 => GoogleFonts.getFont(
    fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static TextStyle get body2 => GoogleFonts.getFont(
    fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
}
