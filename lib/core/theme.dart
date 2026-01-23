import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_provider.dart';

class AppTheme {
  // Private constructor to prevent instantiation
  const AppTheme._();

  // =========================
  // iOS SYSTEM COLORS
  // =========================
  static const Color _iOSBlue = Color(0xFF007AFF);
  static const Color _iOSDarkBlue = Color(0xFF0A84FF);
  static const Color _iOSLightBackground = Color(0xFFF2F2F7);
  static const Color _iOSSecondaryLightBackground = Color(0xFFFFFFFF);
  static const Color _iOSDarkBackground = Color(0xFF000000);
  static const Color _iOSSecondaryDarkBackground = Color(0xFF1C1C1E);
  static const Color _gold = Color(0xFFFFD700);

  // =========================
  // LIGHT THEME (iOS Style)
  // =========================
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: _iOSLightBackground,
    textTheme: _lightTextTheme,
    appBarTheme: _lightAppBarTheme(),
    cardTheme: _lightCardTheme,
    inputDecorationTheme: _inputDecorationTheme(lightColorScheme),
    dropdownMenuTheme: _dropdownMenuTheme(lightColorScheme),
    chipTheme: _chipTheme(lightColorScheme),
    dividerTheme: _dividerTheme(lightColorScheme),
    iconTheme: const IconThemeData(color: Color(0xFF000000)),

    // Apple-style button themes
    elevatedButtonTheme: _elevatedButtonTheme(_iOSBlue, lightColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_iOSBlue, lightColorScheme),
    textButtonTheme: _textButtonTheme(_iOSBlue, lightColorScheme),

    // iOS-style page motion
    pageTransitionsTheme: _cupertinoTransitions,
  );

  // =========================
  // DARK THEME
  // =========================
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: _iOSDarkBackground,
    textTheme: _darkTextTheme,
    appBarTheme: _darkAppBarTheme(_gold),
    cardTheme: _darkCardTheme(_gold),
    inputDecorationTheme: _inputDecorationTheme(
      darkColorScheme,
      overrideFocus: _gold,
    ),
    dropdownMenuTheme: _dropdownMenuTheme(darkColorScheme),
    chipTheme: _chipTheme(darkColorScheme),
    dividerTheme: _dividerTheme(darkColorScheme),

    // Apple-style button themes
    elevatedButtonTheme: _elevatedButtonTheme(_gold, darkColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, darkColorScheme),
    textButtonTheme: _textButtonTheme(_gold, darkColorScheme),

    iconTheme: const IconThemeData(color: Colors.white70),

    pageTransitionsTheme: _cupertinoTransitions,
  );

  // =========================
  // BANGLADESH THEME
  // =========================
  // PREMIUM OLED BANGLADESH THEME ("Golden Bengal")
  static final ThemeData bangladeshTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: bangladeshColorScheme,
    scaffoldBackgroundColor: const Color(0xFF000000), // True OLED Black
    textTheme: _bangladeshTextTheme,
    appBarTheme: _bangladeshAppBarTheme(),
    cardTheme: _bangladeshCardTheme,
    inputDecorationTheme: _inputDecorationTheme(
      bangladeshColorScheme,
      overrideFocus: _gold, // Gold focus for premium feel
    ),
    dropdownMenuTheme: _dropdownMenuTheme(bangladeshColorScheme),
    chipTheme: _chipTheme(bangladeshColorScheme),
    dividerTheme: _dividerTheme(bangladeshColorScheme),

    // Gold & Green Button Styling
    elevatedButtonTheme: _elevatedButtonTheme(
      const Color(0xFF006A4E), // Keep Green for main action background
      bangladeshColorScheme,
    ),
    outlinedButtonTheme: _outlinedButtonTheme(
      _gold, // Gold borders for interactions
      bangladeshColorScheme,
    ),
    textButtonTheme: _textButtonTheme(
      _gold, // Gold text buttons
      bangladeshColorScheme,
    ),

    // Gold Icons for luxury feel
    iconTheme: const IconThemeData(color: _gold),
    primaryIconTheme: const IconThemeData(color: _gold),

    pageTransitionsTheme: _cupertinoTransitions,
  );

  // ─────────────────────────────────────────────
  // TYPOGRAPHY SYSTEM (iOS-Style with Inter)
  // ─────────────────────────────────────────────

  static final TextTheme _lightTextTheme = GoogleFonts.interTextTheme()
      .copyWith(
        bodyLarge: GoogleFonts.inter(
          fontSize: 17, // iOS body size
          height: 1.29, // iOS line height
          letterSpacing: -0.41,
          color: const Color(0xFF000000), // iOS label
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          height: 1.33,
          letterSpacing: -0.23,
          color: const Color(
            0xFF3C3C43,
          ).withOpacity(0.6), // iOS secondary label
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          height: 1.38,
          letterSpacing: -0.08,
          color: const Color(0xFF3C3C43).withOpacity(0.3), // iOS tertiary label
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 34, // iOS large title
          fontWeight: FontWeight.w700, // Bold
          height: 1.18,
          letterSpacing: 0.37,
          color: const Color(0xFF000000),
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600, // Semibold
          height: 1.25,
          letterSpacing: 0.38,
          color: const Color(0xFF000000),
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.29,
          letterSpacing: -0.41,
          color: const Color(0xFF000000),
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.21,
          letterSpacing: 0.36,
          color: const Color(0xFF000000),
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.23,
          letterSpacing: 0.35,
          color: const Color(0xFF000000),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          color: const Color(0xFF007AFF), // iOS blue
        ),
      );

  static final TextTheme _darkTextTheme = GoogleFonts.interTextTheme().copyWith(
    bodyLarge: GoogleFonts.inter(
      fontSize: 17,
      height: 1.29,
      letterSpacing: -0.41,
      color: const Color(0xFFFFFFFF), // iOS dark label
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 15,
      height: 1.33,
      letterSpacing: -0.23,
      color: const Color(
        0xFFEBEBF5,
      ).withOpacity(0.6), // iOS dark secondary label
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 13,
      height: 1.38,
      letterSpacing: -0.08,
      color: const Color(
        0xFFEBEBF5,
      ).withOpacity(0.3), // iOS dark tertiary label
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.18,
      letterSpacing: 0.37,
      color: const Color(0xFFFFFFFF),
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: 0.38,
      color: const Color(0xFFFFFFFF),
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.29,
      letterSpacing: -0.41,
      color: const Color(0xFFFFFFFF),
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.21,
      letterSpacing: 0.36,
      color: const Color(0xFFFFFFFF),
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.23,
      letterSpacing: 0.35,
      color: const Color(0xFFFFFFFF),
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.41,
      color: const Color(0xFF0A84FF), // iOS dark mode blue
    ),
  );

  static final TextTheme _bangladeshTextTheme = GoogleFonts.interTextTheme()
      .copyWith(
        // ===== BODY STYLES (White for readability) =====
        bodyLarge: GoogleFonts.inter(
          fontSize: 17,
          height: 1.29,
          letterSpacing: -0.41,
          color: const Color(0xFFFFFFFF), // Bright White
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          height: 1.33,
          letterSpacing: -0.23,
          color: const Color(0xFFFFFFFF).withOpacity(0.9), // Near White
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          height: 1.38,
          letterSpacing: -0.08,
          color: const Color(0xFFFFFFFF).withOpacity(0.75), // Soft White
        ),
        // ===== HEADLINE STYLES (Gold for premium) =====
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.21,
          color: _gold, // Gold Headline
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.23,
          letterSpacing: 0.35,
          color: _gold, // Gold
        ),
        // ===== TITLE STYLES (White/Gold for card titles) =====
        titleLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.18,
          letterSpacing: 0.37,
          color: const Color(0xFFFFFFFF), // White for large titles
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _gold, // Gold Title
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.29,
          letterSpacing: -0.41,
          color: const Color(
            0xFFFFFFFF,
          ), // White for card titles (NewsCard uses this)
        ),
        // ===== LABEL STYLES (Gold for interactive) =====
        labelLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          color: _gold, // Gold labels
        ),
      );

  // ─────────────────────────────────────────────
  // APP BAR THEMES
  // ─────────────────────────────────────────────

  static AppBarTheme _lightAppBarTheme() => AppBarTheme(
    backgroundColor: _iOSLightBackground.withOpacity(0.94), // iOS translucent
    foregroundColor: const Color(0xFF000000),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(
      color: Color(0xFF000000),
    ), // Ensure icons are black
    actionsIconTheme: const IconThemeData(
      color: Color(0xFF000000),
    ), // Ensure action icons are black
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20, // Consistent page title size
      fontWeight: FontWeight.w600,
      letterSpacing: 0.38,
      color: const Color(0xFF000000),
    ),
    scrolledUnderElevation: 0,
  );

  static AppBarTheme _darkAppBarTheme(Color gold) => AppBarTheme(
    // Use lighter iOS dark grey (#1C1C1E) instead of pure black
    backgroundColor: const Color(0xFF1C1C1E).withOpacity(0.94),
    foregroundColor: const Color(0xFFFFFFFF),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
    actionsIconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.38,
      color: const Color(0xFFFFFFFF),
    ),
    scrolledUnderElevation: 0,
  );

  static AppBarTheme _bangladeshAppBarTheme() => AppBarTheme(
    backgroundColor: Colors.black.withOpacity(0.85), // OLED Glass
    foregroundColor: _gold, // Gold text/icons
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: _gold),
    actionsIconTheme: const IconThemeData(color: _gold),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: _gold, // Gold Title
    ),
    scrolledUnderElevation: 0,
  );

  // ─────────────────────────────────────────────
  // CARD THEMES
  // ─────────────────────────────────────────────

  static final CardThemeData _lightCardTheme = CardThemeData(
    color: _iOSSecondaryLightBackground,
    elevation: 1, // iOS-style subtle shadow
    shadowColor: Colors.black.withOpacity(0.05),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), // iOS corner radius
      side: BorderSide(
        color: const Color(0xFF3C3C43).withOpacity(0.08), // Subtle border
        width: 0.5,
      ),
    ),
  );

  static CardThemeData _darkCardTheme(Color gold) => CardThemeData(
    color: const Color(
      0xFF121212,
    ), // Dark Grey Surface (Better contrast vs Black background)
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Colors.white.withOpacity(0.08), // More subtle border
        width: 0.8,
      ),
    ),
  );

  static const CardThemeData _bangladeshCardTheme = CardThemeData(
    color: Color(0xFF050505), // Nearly black surface
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(
        color: _gold, // Premium Gold Border
        width: 0.8,
      ),
    ),
  );

  // ─────────────────────────────────────────────
  // BUTTON THEMES (Apple-Inspired)
  // ─────────────────────────────────────────────

  static ElevatedButtonThemeData _elevatedButtonTheme(
    Color accent,
    ColorScheme scheme,
  ) {
    final bool isDark = scheme.brightness == Brightness.dark;

    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withOpacity(0.12);
          }
          if (states.contains(WidgetState.pressed)) {
            return accent.withOpacity(0.8);
          }
          return accent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withOpacity(0.38);
          }
          return isDark ? Colors.white : Colors.white;
        }),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return 1;
          if (states.contains(WidgetState.hovered)) return 6;
          return 3; // Apple-style subtle elevation
        }),
        shadowColor: WidgetStateProperty.all(Colors.black.withOpacity(0.3)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // iOS style
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        minimumSize: WidgetStateProperty.all(const Size(88, 48)),
        // Smooth animation
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
    Color accent,
    ColorScheme scheme,
  ) {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withOpacity(0.38);
          }
          return accent;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return accent.withOpacity(0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return accent.withOpacity(0.04);
          }
          return Colors.transparent;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(
              color: scheme.onSurface.withOpacity(0.12),
              width: 1.5,
            );
          }
          return BorderSide(color: accent, width: 1.5);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        minimumSize: WidgetStateProperty.all(const Size(88, 48)),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(
    Color accent,
    ColorScheme scheme,
  ) {
    return TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withOpacity(0.38);
          }
          return accent;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return accent.withOpacity(0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return accent.withOpacity(0.08);
          }
          return Colors.transparent;
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        minimumSize: WidgetStateProperty.all(const Size(64, 40)),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme scheme, {
    Color? overrideFocus,
  }) {
    final focus = overrideFocus ?? scheme.primary;
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface.withOpacity(0.95),
      border: _outline(),
      focusedBorder: _outline(color: focus),
    );
  }

  static OutlineInputBorder _outline({Color? color}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color ?? Colors.transparent),
  );

  static DropdownMenuThemeData _dropdownMenuTheme(ColorScheme scheme) =>
      DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            scheme.surface.withOpacity(0.97),
          ),
        ),
      );

  static ChipThemeData _chipTheme(ColorScheme scheme) => ChipThemeData(
    backgroundColor: scheme.surface,
    selectedColor: scheme.primaryContainer,
    labelStyle: TextStyle(color: scheme.onSurface),
  );

  static DividerThemeData _dividerTheme(ColorScheme scheme) => DividerThemeData(
    thickness: 0.5, // iOS hairline
    color: scheme.onSurface.withOpacity(0.12),
  );

  // ─────────────────────────────────────────────
  // SYSTEM CONSTANTS
  // ─────────────────────────────────────────────

  static const PageTransitionsTheme _cupertinoTransitions =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      );
}

// ─────────────────────────────────────────────
// COLOR SCHEMES
// ─────────────────────────────────────────────

const ColorScheme lightColorScheme = ColorScheme.light(
  primary: Color(0xFF007AFF), // iOS blue
  secondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFF5AC8FA), // iOS teal
  surface: Color(0xFFF2F2F7), // iOS system background
  surfaceContainerHighest: Color(0xFFFFFFFF), // iOS secondary background
  onSurfaceVariant: Color(0xFF3C3C43), // iOS secondary label
  outline: Color(0xFF3C3C43), // iOS separator
);

const ColorScheme darkColorScheme = ColorScheme.dark(
  primary: Color(0xFF0A84FF), // iOS dark blue
  secondary: Color(0xFF1C1C1E),
  tertiary: Color(0xFF64D2FF), // iOS dark teal
  surface: Color(0xFF000000), // True black for OLED
  surfaceContainerHighest: Color(0xFF1C1C1E), // iOS dark secondary background
  onSurfaceVariant: Color(0xFFEBEBF5), // iOS dark secondary label
  outline: Color(0xFFEBEBF5), // iOS dark separator
);

const ColorScheme bangladeshColorScheme = ColorScheme.dark(
  primary: Color(0xFF006A4E), // Emerald Green
  onPrimary: Colors.white,
  secondary: Color(0xFFFFD700), // Gold Accent
  tertiary: Color(0xFFFFD700),
  surface: Color(0xFF000000), // True Black
  surfaceContainerHighest: Color(0xFF0A0A0A), // Very subtle off-black
  outline: Color(0xFFFFD700), // Gold outlines
);

// ─────────────────────────────────────────────
// GRADIENT UTILITY
// ─────────────────────────────────────────────

class AppGradients {
  // Private constructor to prevent instantiation
  const AppGradients._();

  static List<Color> getGradientColors(AppThemeMode mode) {
    // Legacy support: defaults to Highlight behaviors (White for Dark Mode)
    // Use getBackgroundGradient for Screens!
    switch (mode) {
      case AppThemeMode.light:
        return const [Color(0xFFFFFFFF), Color(0xFFE0E0E0)];
      case AppThemeMode.bangladesh:
        return const [Color(0xFFFFD700), Color(0xFF006A4E)];
      case AppThemeMode.dark:
      default:
        return [Colors.white, Colors.white12];
    }
  }

  // Use this for Screen Backgrounds
  static List<Color> getBackgroundGradient(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
      case AppThemeMode.light:
        return const [Color(0xFFF2F2F7), Color(0xFFE5E5EA)]; // iOS Light Greys
      case AppThemeMode.bangladesh:
        // Bangladesh Flag Colors: Green (land) + Red (sun/blood)
        // Start: Deep Emerald Green #0D3830 (lush greenery)
        // End: Deep Crimson #3D0F15 (rising sun / blood of martyrs)
        return const [Color(0xFF0D3830), Color(0xFF3D0F15)];
      case AppThemeMode.dark:
        // Improved Contrast: Darker background for better text visibility
        return const [Color(0xFF050505), Color(0xFF121212)];
      case AppThemeMode.amoled:
        // Pure black for AMOLED displays
        return const [Color(0xFF000000), Color(0xFF000000)];
    }
  }

  // Use this for Borders, Text, Icons
  static List<Color> getHighlightGradient(AppThemeMode mode) {
    return getGradientColors(mode);
  }
}
