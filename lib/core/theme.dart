import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'enums/theme_mode.dart';
import 'design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primaryBlue = Color(0xFF0061A4);
  static const Color _primaryDarkBlue = Color(0xFF99CBFF);
  static const Color _lightBackground = Color(0xFFF8F9FF);
  static const Color _darkBackground = AppColors.darkBackground;
  static const Color _gold = AppColors.gold;

  static const Color _secondaryLight = Color(0xFF535F70); 
  static const Color _secondaryDark = Color(0xFFBFC8D8); 

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: _lightBackground,
    textTheme: _lightTextTheme,
    appBarTheme: _lightAppBarTheme(),
    cardTheme: _lightCardTheme,
    inputDecorationTheme: _inputDecorationTheme(lightColorScheme),
    dropdownMenuTheme: _dropdownMenuTheme(lightColorScheme),
    chipTheme: _chipTheme(lightColorScheme),
    dividerTheme: _dividerTheme(lightColorScheme),
    iconTheme: const IconThemeData(color: Color(0xFF191C1E), size: 24),

    elevatedButtonTheme: _elevatedButtonTheme(_primaryBlue, lightColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_primaryBlue, lightColorScheme),
    textButtonTheme: _textButtonTheme(_primaryBlue, lightColorScheme),

    pageTransitionsTheme: _androidTransitions,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: _darkBackground,
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

    elevatedButtonTheme: _elevatedButtonTheme(_gold, darkColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, darkColorScheme),
    textButtonTheme: _textButtonTheme(_gold, darkColorScheme),

    iconTheme: const IconThemeData(color: Color(0xFFE2E2E6), size: 24),

    pageTransitionsTheme: _androidTransitions,
  );

  static final ThemeData _amoledTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: amoledColorScheme,
    scaffoldBackgroundColor: Colors.black,
    textTheme: _darkTextTheme,
    appBarTheme: _amoledAppBarTheme(),
    cardTheme: _amoledCardTheme,
    inputDecorationTheme: _inputDecorationTheme(
      amoledColorScheme,
      overrideFocus: _gold,
    ),
    dropdownMenuTheme: _dropdownMenuTheme(amoledColorScheme),
    chipTheme: _chipTheme(amoledColorScheme),
    dividerTheme: _dividerTheme(amoledColorScheme),

    elevatedButtonTheme: _elevatedButtonTheme(_gold, amoledColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, amoledColorScheme),
    textButtonTheme: _textButtonTheme(_gold, amoledColorScheme),

    iconTheme: const IconThemeData(color: Color(0xFFEBEBF5), size: 22),

    pageTransitionsTheme: _androidTransitions,
  );

  static ThemeData get amoledTheme => _amoledTheme;

  static final ThemeData bangladeshTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: bangladeshColorScheme,
    scaffoldBackgroundColor: const Color(0xFF000000),
    textTheme: _bangladeshTextTheme,
    appBarTheme: _bangladeshAppBarTheme(),
    cardTheme: _bangladeshCardTheme,
    inputDecorationTheme: _inputDecorationTheme(
      bangladeshColorScheme,
      overrideFocus: _gold,
    ),
    dropdownMenuTheme: _dropdownMenuTheme(bangladeshColorScheme),
    chipTheme: _chipTheme(bangladeshColorScheme),
    dividerTheme: _dividerTheme(bangladeshColorScheme),

    elevatedButtonTheme: _elevatedButtonTheme(
      _gold,
      bangladeshColorScheme,
    ),
    outlinedButtonTheme: _outlinedButtonTheme(
      _gold,
      bangladeshColorScheme,
    ),
    textButtonTheme: _textButtonTheme(
      _gold,
      bangladeshColorScheme,
    ),

    iconTheme: const IconThemeData(color: _gold, size: 22),
    primaryIconTheme: const IconThemeData(color: _gold, size: 22),

    pageTransitionsTheme: _androidTransitions,
  );


  // PREMIUM TYPOGRAPHY HELPER
  // Standardized on Inter for best Android readability and premium feel
  static TextStyle _fontStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required double letterSpacing,
    required Color color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
      decoration: TextDecoration.none,
    );
  }

  static final TextTheme _lightTextTheme = TextTheme(
    displayLarge: _fontStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, color: Colors.black, height: 1.12),
    displayMedium: _fontStyle(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.black, height: 1.15),
    displaySmall: _fontStyle(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.black, height: 1.22),
    
    headlineLarge: _fontStyle(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.black),
    headlineMedium: _fontStyle(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.black),
    headlineSmall: _fontStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.black),
    
    titleLarge: _fontStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0, color: Colors.black),
    titleMedium: _fontStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: Colors.black), 
    titleSmall: _fontStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: Colors.black),
    
    bodyLarge: _fontStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: Colors.black),
    bodyMedium: _fontStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: _secondaryLight),
    bodySmall: _fontStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: _secondaryLight),
    
    labelLarge: _fontStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: _primaryBlue),
  );

  static final TextTheme _darkTextTheme = TextTheme(
    displayLarge: _fontStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, color: Colors.white, height: 1.12),
    displayMedium: _fontStyle(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.white, height: 1.15),
    displaySmall: _fontStyle(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.white, height: 1.22),
    
    headlineLarge: _fontStyle(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.white),
    headlineMedium: _fontStyle(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.white),
    headlineSmall: _fontStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 0, color: Colors.white),
    
    titleLarge: _fontStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0, color: Colors.white),
    titleMedium: _fontStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: Colors.white), 
    titleSmall: _fontStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: Colors.white),

    bodyLarge: _fontStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: Colors.white),
    bodyMedium: _fontStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: _secondaryDark),
    bodySmall: _fontStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: _secondaryDark),
    
    labelLarge: _fontStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: _primaryDarkBlue),
  );

  static final TextTheme _bangladeshTextTheme = TextTheme(
    displayLarge: _fontStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: Colors.white, height: 1.2),
    displayMedium: _fontStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.36, color: Colors.white, height: 1.2),
    displaySmall: _fontStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.35, color: Colors.white, height: 1.2),
    
    headlineMedium: _fontStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38, color: Colors.white, height: 1.2),
    headlineSmall: _fontStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41, color: Colors.white, height: 1.3),
    
    titleLarge: _fontStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: Colors.white),
    titleMedium: _fontStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38, color: Colors.white), 
    titleSmall: _fontStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.23, color: Colors.white),

    bodyLarge: _fontStyle(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.41, color: Colors.white, height: 1.3),
    bodyMedium: _fontStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.23, color: const Color(0xFFEBEBF5), height: 1.4),
    bodySmall: _fontStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08, color: const Color(0xFFEBEBF5), height: 1.4),
    
    labelLarge: _fontStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41, color: _gold),
  );


  static AppBarTheme _lightAppBarTheme() => AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: const Color(0xFF191C1E),
    elevation: 0,
    centerTitle: false, 
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(
      color: Color(0xFF191C1E),
      size: 24,
    ),
    actionsIconTheme: const IconThemeData(
      color: Color(0xFF191C1E),
      size: 24,
    ),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF191C1E),
    ),
    scrolledUnderElevation: 3,
  );

  static AppBarTheme _darkAppBarTheme(Color gold) => AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: const Color(0xFFE2E2E6),
    elevation: 0,
    centerTitle: false, 
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: Color(0xFFE2E2E6), size: 24),
    actionsIconTheme: const IconThemeData(color: Color(0xFFE2E2E6), size: 24),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: const Color(0xFFE2E2E6),
    ),
    scrolledUnderElevation: 3,
  );

  static AppBarTheme _amoledAppBarTheme() => AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: const Color(0xFFFFFFFF),
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: Color(0xFFFFFFFF), size: 22),
    actionsIconTheme: const IconThemeData(color: Color(0xFFFFFFFF), size: 22),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.38,
      color: const Color(0xFFFFFFFF),
    ),
    scrolledUnderElevation: 0,
  );

  static AppBarTheme _bangladeshAppBarTheme() => AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: _gold,
    elevation: 0,
    centerTitle: false, // Android Native Pattern
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: _gold, size: 22),
    actionsIconTheme: const IconThemeData(color: _gold, size: 22),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: Colors.white,
    ),
    scrolledUnderElevation: 0,
  );


  static final CardThemeData _lightCardTheme = CardThemeData(
    color: const Color(0xFFFFFFFF),
    elevation: 0, 
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16), 
      side: const BorderSide(
        color: Color(0xFFDFE2EB),
      ),
    ),
  );

  static CardThemeData _darkCardTheme(Color gold) => CardThemeData(
    color: AppColors.darkSurface,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(
        color: AppColors.darkSecondary,
      ),
    ),
  );

  static final CardThemeData _amoledCardTheme = CardThemeData(
    color: Colors.black,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(
        color: Color(0xFF1F1F1F),
      ),
    ),
  );

  static const CardThemeData _bangladeshCardTheme = CardThemeData(
    color: Color(0xFF1C1C1E),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(
        color: _gold,
      ),
    ),
  );


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
          if (states.contains(WidgetState.hovered)) return 4;
          return 0; // Flat premium look
        }),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), 
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        minimumSize: WidgetStateProperty.all(const Size(88, 50)),
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
            return accent.withOpacity(0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return accent.withOpacity(0.05);
          }
          return Colors.transparent;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(
              color: scheme.onSurface.withOpacity(0.12),
            );
          }
          return BorderSide(color: accent);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        minimumSize: WidgetStateProperty.all(const Size(88, 50)),
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
        minimumSize: WidgetStateProperty.all(const Size(64, 44)),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme scheme, {
    Color? overrideFocus,
  }) {
    final focus = overrideFocus ?? scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF2F2F7),
      border: _outline(),
      focusedBorder: _outline(color: focus),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static OutlineInputBorder _outline({Color? color}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color ?? Colors.transparent, width: 1.5),
  );

  static DropdownMenuThemeData _dropdownMenuTheme(ColorScheme scheme) =>
      DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            scheme.surface,
          ),
        ),
      );

  static ChipThemeData _chipTheme(ColorScheme scheme) => ChipThemeData(
    backgroundColor: scheme.surface,
    selectedColor: scheme.primaryContainer,
    labelStyle: TextStyle(color: scheme.onSurface),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  static DividerThemeData _dividerTheme(ColorScheme scheme) => DividerThemeData(
    thickness: 1, 
    color: scheme.onSurface.withOpacity(0.08),
  );

  static const PageTransitionsTheme _androidTransitions =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(), // Modern Android
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      );
}

// ─────────────────────────────────────────────
// COLOR SCHEMES
// ─────────────────────────────────────────────

const ColorScheme lightColorScheme = ColorScheme.light(
  primary: Color(0xFF0061A4),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD1E4FF),
  onPrimaryContainer: Color(0xFF001D36),
  secondary: Color(0xFF535F70),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFD7E3F7),
  onSecondaryContainer: Color(0xFF101C2B),
  tertiary: Color(0xFF6B5778),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF2DAFF),
  onTertiaryContainer: Color(0xFF251431),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  background: Color(0xFFF8F9FF),
  onBackground: Color(0xFF191C1E),
  surface: Color(0xFFF8F9FF),
  onSurface: Color(0xFF191C1E),
  surfaceVariant: Color(0xFFDFE2EB),
  onSurfaceVariant: Color(0xFF43474E),
  outline: Color(0xFF73777F),
);

const ColorScheme darkColorScheme = ColorScheme.dark(
  primary: Color(0xFF99CBFF),
  onPrimary: Color(0xFF003355),
  primaryContainer: Color(0xFF00497B),
  onPrimaryContainer: Color(0xFFD1E4FF),
  secondary: Color(0xFFBFC8D8),
  onSecondary: Color(0xFF29313E),
  secondaryContainer: Color(0xFF3F4756),
  onSecondaryContainer: Color(0xFFD7E3F7),
  tertiary: Color(0xFFD7BEE4),
  onTertiary: Color(0xFF3B2948),
  tertiaryContainer: Color(0xFF523F5F),
  onTertiaryContainer: Color(0xFFF3DAFF),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  background: AppColors.darkBackground,
  onBackground: Color(0xFFE2E2E6),
  surface: AppColors.darkSurface,
  onSurface: Color(0xFFE2E2E6),
  surfaceVariant: Color(0xFF43474E),
  onSurfaceVariant: Color(0xFFC3C7CF),
  outline: Color(0xFF8D9199),
);

const ColorScheme amoledColorScheme = ColorScheme.dark(
  primary: Color(0xFF0A84FF),
  secondary: Color(0xFF000000),
  tertiary: Color(0xFF64D2FF),
  surface: Color(0xFF000000),
  surfaceContainerHighest: Color(0xFF0B0B0B),
  onSurfaceVariant: Color(0xFFEBEBF5),
  outline: Color(0xFF303030),
);

const ColorScheme bangladeshColorScheme = ColorScheme.dark(
  primary: Color(0xFF006A4E),
  onPrimary: Colors.white,
  secondary: Color(0xFFFFD700),
  tertiary: Color(0xFFFFD700),
  surface: Color(0xFF000000),
  surfaceContainerHighest: Color(0xFF0A0A0A),
  outline: Color(0xFFFFD700),
);

// ─────────────────────────────────────────────
// GRADIENT UTILITY
// ─────────────────────────────────────────────

class AppGradients {
  const AppGradients._();

  static List<Color> getGradientColors(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return const [Color(0xFFFFFFFF), Color(0xFFE0E0E0)];
      case AppThemeMode.bangladesh:
        return const [Color(0xFFFFD700), Color(0xFF006A4E)];
      case AppThemeMode.amoled:
        return const [Color(0xFF000000), Color(0xFF000000)];
      case AppThemeMode.dark:
      default:
        return [Colors.white, Colors.white12];
    }
  }

  static List<Color> getBackgroundGradient(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
      case AppThemeMode.light:
        return const [Color(0xFFF2F2F7), Color(0xFFE5E5EA)]; 
      case AppThemeMode.bangladesh:
        return const [Color(0xFF006A4E), Color(0xFF450D15)]; // Proper Bangladesh Green to Deep Maroon
      case AppThemeMode.dark:
        return [AppColors.darkBackground, const Color(0xFF2A2626)]; // Deeper mocha for the bottom
      case AppThemeMode.amoled:
        return const [Color(0xFF000000), Color(0xFF000000)];
    }
  }

  static List<Color> getHighlightGradient(AppThemeMode mode) {
    return getGradientColors(mode);
  }
}
