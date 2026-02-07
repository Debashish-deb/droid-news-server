import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'enums/theme_mode.dart';
import 'design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const Color _iOSBlue = AppColors.iOSBlue;
  static const Color _iOSDarkBlue = AppColors.iOSDarkBlue;
  static const Color _iOSLightBackground = Color(0xFFF2F2F7);
  static const Color _iOSSecondaryLightBackground = Color(0xFFFFFFFF);
  static const Color _iOSDarkBackground = AppColors.darkBackground;
  static const Color _gold = AppColors.gold;

  static const Color _iOSSecondaryLight = Color(0xFF6E6E73); // System Gray
  static const Color _iOSSecondaryDark = Color(0xFF8E8E93); // System Gray 2

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
    iconTheme: const IconThemeData(color: Color(0xFF000000), size: 22),

    elevatedButtonTheme: _elevatedButtonTheme(_iOSBlue, lightColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_iOSBlue, lightColorScheme),
    textButtonTheme: _textButtonTheme(_iOSBlue, lightColorScheme),

    pageTransitionsTheme: _cupertinoTransitions,
  );

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

    elevatedButtonTheme: _elevatedButtonTheme(_gold, darkColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, darkColorScheme),
    textButtonTheme: _textButtonTheme(_gold, darkColorScheme),

    iconTheme: const IconThemeData(color: Color(0xFFEBEBF5), size: 22),

    pageTransitionsTheme: _cupertinoTransitions,
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

    pageTransitionsTheme: _cupertinoTransitions,
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
      const Color(0xFF006A4E),
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

    pageTransitionsTheme: _cupertinoTransitions,
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
    displayLarge: _fontStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: Colors.black, height: 1.2),
    displayMedium: _fontStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.36, color: Colors.black, height: 1.2),
    displaySmall: _fontStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.35, color: Colors.black, height: 1.2),
    
    headlineMedium: _fontStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38, color: Colors.black, height: 1.2),
    headlineSmall: _fontStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41, color: Colors.black, height: 1.3),
    
    titleLarge: _fontStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: Colors.black),
    titleMedium: _fontStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38, color: Colors.black), 
    titleSmall: _fontStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.23, color: Colors.black),
    
    bodyLarge: _fontStyle(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.41, color: Colors.black, height: 1.3),
    bodyMedium: _fontStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.23, color: _iOSSecondaryLight, height: 1.4),
    bodySmall: _fontStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08, color: _iOSSecondaryLight, height: 1.4),
    
    labelLarge: _fontStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41, color: _iOSBlue), // Buttons
  );

  static final TextTheme _darkTextTheme = TextTheme(
    displayLarge: _fontStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: Colors.white, height: 1.2),
    displayMedium: _fontStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.36, color: Colors.white, height: 1.2),
    displaySmall: _fontStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.35, color: Colors.white, height: 1.2),
    
    headlineMedium: _fontStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38, color: Colors.white, height: 1.2),
    headlineSmall: _fontStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41, color: Colors.white, height: 1.3),
    
    titleLarge: _fontStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: Colors.white),
    titleMedium: _fontStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38, color: Colors.white), 
    titleSmall: _fontStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.23, color: Colors.white),

    bodyLarge: _fontStyle(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.41, color: Colors.white, height: 1.3),
    bodyMedium: _fontStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.23, color: _iOSSecondaryDark, height: 1.4),
    bodySmall: _fontStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08, color: _iOSSecondaryDark, height: 1.4),
    
    labelLarge: _fontStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41, color: _iOSDarkBlue),
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
    backgroundColor: _iOSLightBackground,
    foregroundColor: const Color(0xFF000000),
    elevation: 0,
    centerTitle: false, // Android Native Pattern
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(
      color: Color(0xFF000000),
      size: 22,
    ),
    actionsIconTheme: const IconThemeData(
      color: Color(0xFF000000),
      size: 22,
    ),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.38,
      color: const Color(0xFF000000),
    ),
    scrolledUnderElevation: 0,
  );

  static AppBarTheme _darkAppBarTheme(Color gold) => AppBarTheme(
    backgroundColor: AppColors.darkSurface,
    foregroundColor: const Color(0xFFFFFFFF),
    elevation: 0,
    centerTitle: false, // Android Native Pattern
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: Color(0xFFFFFFFF), size: 22),
    actionsIconTheme: const IconThemeData(color: Color(0xFFFFFFFF), size: 22),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.38,
      color: const Color(0xFFFFFFFF),
    ),
    scrolledUnderElevation: 0,
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
      fontWeight: FontWeight.w600,
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
    color: _iOSSecondaryLightBackground,
    elevation: 0, 
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16), 
      side: const BorderSide(
        color: Color(0xFFE5E5EA),
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
    borderSide: BorderSide(color: color ?? Colors.transparent),
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

  static const PageTransitionsTheme _cupertinoTransitions =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), 
        },
      );
}

// ─────────────────────────────────────────────
// COLOR SCHEMES
// ─────────────────────────────────────────────

const ColorScheme lightColorScheme = ColorScheme.light(
  primary: Color(0xFF007AFF), 
  secondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFF5AC8FA), 
  surface: Color(0xFFF2F2F7), 
  surfaceContainerHighest: Color(0xFFFFFFFF), 
  onSurfaceVariant: Color(0xFF3C3C43), 
  outline: Color(0xFF3C3C43), 
);

const ColorScheme darkColorScheme = ColorScheme.dark(
  primary: AppColors.iOSDarkBlue, 
  secondary: AppColors.darkSurface, 
  tertiary: Color(0xFF64D2FF),
  surface: AppColors.darkBackground,
  surfaceContainerHighest: AppColors.darkSurface, 
  onSurfaceVariant: Color(0xFFEBEBF5), 
  outline: AppColors.darkSecondary,
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
        return const [Color(0xFF0D3830), Color(0xFF3D0F15)];
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
