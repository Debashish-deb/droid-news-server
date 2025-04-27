// path: lib/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color.fromARGB(255, 24, 45, 64),
    secondary: const Color(0xFFC89B3C),
    tertiary: const Color.fromARGB(255, 70, 58, 80),
    brightness: Brightness.light,
  );

  static final darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0A0F1F),
    secondary: const Color.fromARGB(255, 0, 0, 0),
    tertiary: const Color.fromARGB(255, 98, 39, 59),
    brightness: Brightness.dark,
  );

  static ThemeData buildLightTheme() => ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color.fromARGB(255, 129, 146, 181),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightColorScheme.secondary, width: 2),
          ),
        ),
      );

  static ThemeData buildDarkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: darkColorScheme.copyWith(
    background: const Color(0xFF121417), // dark ash background
    surface: const Color(0xFF1A1D20),
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121417),
  cardColor: const Color(0xFF1C1F22),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF181B1E),
    foregroundColor: Colors.white,
  ),
  textTheme: GoogleFonts.poppinsTextTheme().apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF202326),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
    ),
    hintStyle: const TextStyle(color: Colors.white60),
    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    floatingLabelStyle: const TextStyle(color: Colors.white),
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
  iconTheme: const IconThemeData(color: Colors.white70),
);

static ThemeData buildBangladeshTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF006A4E), // Flag green
    primary: const Color(0xFF006A4E),
    secondary: const Color(0xFFF42A41), // Red circle
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF022d1e),
  textTheme: GoogleFonts.poppinsTextTheme().apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF006A4E),
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0c4634),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFF42A41), width: 2),
    ),
    hintStyle: const TextStyle(color: Colors.white70),
    labelStyle: const TextStyle(color: Colors.white),
    floatingLabelStyle: const TextStyle(color: Colors.white),
  ),
);
}