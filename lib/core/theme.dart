import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_provider.dart';

class AppTheme {
  static ThemeData buildLightTheme() => ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightColorScheme.background.withOpacity(0.95),
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          bodyLarge: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
          bodyMedium: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
          headlineLarge: GoogleFonts.poppins(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
          headlineMedium: GoogleFonts.poppins(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
          titleLarge: GoogleFonts.poppins(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          titleMedium: GoogleFonts.poppins(color: Colors.black87, fontSize: 18),
          labelLarge: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.surface.withOpacity(0.8),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: Colors.white.withOpacity(0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: Colors.black26,
        ),
        inputDecorationTheme: _inputDecorationTheme(lightColorScheme),
        dropdownMenuTheme: _dropdownMenuTheme(lightColorScheme),
        chipTheme: _chipTheme(lightColorScheme),
      );

  static ThemeData buildDarkTheme() {
    const gold = Color(0xFFFFD700);
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme.copyWith(
        background: const Color(0xFF121417),
        surface: const Color(0xFF1A1D20).withOpacity(0.6),
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121417).withOpacity(0.95),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        bodyLarge: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
        bodyMedium: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
        headlineLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.poppins(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.poppins(color: Colors.white70, fontSize: 18),
        labelLarge: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A1D20).withOpacity(0.6),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: gold.withOpacity(0.4), blurRadius: 8)],
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1C1F22).withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: gold, width: 2),
        ),
        elevation: 12,
        shadowColor: gold.withOpacity(0.3),
      ),
      inputDecorationTheme: _inputDecorationTheme(darkColorScheme, overrideFocus: gold),
      dropdownMenuTheme: _dropdownMenuTheme(darkColorScheme),
      chipTheme: _chipTheme(darkColorScheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1D20).withOpacity(0.6),
          side: const BorderSide(color: gold, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          shadowColor: gold.withOpacity(0.4),
          textStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }

  static ThemeData buildBangladeshTheme() => ThemeData(
        useMaterial3: true,
        colorScheme: bangladeshColorScheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bangladeshColorScheme.background.withOpacity(0.95),
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          bodyLarge: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          bodyMedium: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
          headlineLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          headlineMedium: GoogleFonts.poppins(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold),
          titleLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          titleMedium: GoogleFonts.poppins(color: Colors.white70, fontSize: 18),
          labelLarge: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bangladeshColorScheme.surface.withOpacity(0.8),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: bangladeshColorScheme.surface.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFF0000), width: 2),
          ),
          elevation: 10,
          shadowColor: Colors.black45,
        ),
        inputDecorationTheme: _inputDecorationTheme(bangladeshColorScheme, overrideFocus: const Color(0xFFFF0000)),
        dropdownMenuTheme: _dropdownMenuTheme(bangladeshColorScheme),
        chipTheme: _chipTheme(bangladeshColorScheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: bangladeshColorScheme.surface.withOpacity(0.3),
            side: const BorderSide(color: Color(0xFFFF0000), width: 2),
            elevation: 6,
            shadowColor: Colors.red.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      );

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme, {Color? overrideFocus}) {
    final focusColor = overrideFocus ?? scheme.secondary;
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focusColor, width: 2)),
      hintStyle: TextStyle(color: scheme.brightness == Brightness.dark ? Colors.white60 : Colors.black54),
      labelStyle: TextStyle(color: scheme.brightness == Brightness.dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
      floatingLabelStyle: TextStyle(color: scheme.brightness == Brightness.dark ? Colors.white : scheme.primary),
    );
  }

  static DropdownMenuThemeData _dropdownMenuTheme(ColorScheme scheme) {
    return DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: MaterialStateProperty.all(
          scheme.brightness == Brightness.dark ? scheme.surface.withOpacity(0.8) : Colors.white,
        ),
        shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  static ChipThemeData _chipTheme(ColorScheme scheme) {
    return ChipThemeData(
      brightness: scheme.brightness,
      backgroundColor: scheme.surfaceVariant,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.onSurface.withOpacity(0.12),
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(color: scheme.onPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: StadiumBorder(side: BorderSide(color: scheme.onSurface.withOpacity(0.12))),
    );
  }
}

final ColorScheme lightColorScheme = ColorScheme.light(
  primary: const Color(0xFF1565C0),
  secondary: const Color(0xFF42A5F5),
  background: const Color(0xFFE3F2FD),
  surface: const Color(0xFFBBDEFB),
);

final ColorScheme darkColorScheme = ColorScheme.dark(
  primary: const Color(0xFF42A5F5),
  secondary: const Color(0xFF1565C0),
  background: const Color(0xFF121417),
  surface: const Color(0xFF1A1D20),
);

final ColorScheme bangladeshColorScheme = ColorScheme.dark(
  primary: const Color.fromARGB(255, 0, 96, 37),
  secondary: const Color(0xFF004D25),
  background: const Color(0xFF000E0B),
  surface: const Color(0xFF002218),
);

class AppGradients {
  static List<Color> getGradientColors(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return [Colors.blue.shade300, Colors.blue.shade100];
      case AppThemeMode.bangladesh:
        return [const Color.fromARGB(255, 1, 86, 34), const Color(0xFF002218)];
      case AppThemeMode.dark:
      default:
        return [Colors.black87, Colors.grey.shade900];
    }
  }
}