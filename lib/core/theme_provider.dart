import 'package:flutter/material.dart';

/// Defines the available theme modes for the app.
enum AppThemeMode {
  light,
  dark,
  bangladesh,
}

/// Provides theme state management and glassmorphic utilities.
class ThemeProvider with ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.light;

  /// Returns the current app theme mode.
  AppThemeMode get appThemeMode => _currentTheme;

  /// Returns the corresponding [ThemeMode] based on [AppThemeMode].
  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppThemeMode.dark:
      case AppThemeMode.bangladesh:
        return ThemeMode.dark;
      case AppThemeMode.light:
      default:
        return ThemeMode.light;
    }
  }

  /// Changes the app theme to the given [AppThemeMode].
  void toggleTheme(AppThemeMode mode) {
    if (_currentTheme != mode) {
      _currentTheme = mode;
      notifyListeners();
    }
  }

  /// Semi-transparent 'glass' overlay color for panels.
  Color get glassColor {
    switch (_currentTheme) {
      case AppThemeMode.dark:
        return Colors.black.withOpacity(0.3);
      case AppThemeMode.bangladesh:
        return const Color(0xFF00796B).withOpacity(0.3);
      case AppThemeMode.light:
      default:
        return Colors.white.withOpacity(0.3);
    }
  }

  /// Golden border color for glass panels when in dark mode.
  Color get borderColor {
    return _currentTheme == AppThemeMode.dark
        ? const Color(0xFFFFD700)
        : Colors.white.withOpacity(0.2);
  }

  /// A subtle frosted shadow for glass panels.
  List<BoxShadow> get glassShadows => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.05),
          blurRadius: 2,
          offset: const Offset(0, -1),
        ),
      ];

  /// Floating/glow text style to boost visibility on glass.
  TextStyle floatingTextStyle({
    Color? color,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    final baseColor = 
        color ?? (_currentTheme == AppThemeMode.dark ? Colors.white : Colors.black);
    return TextStyle(
      color: baseColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      shadows: [
        Shadow(
          color: baseColor.withOpacity(0.25),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        Shadow(
          color: baseColor.withOpacity(0.15),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Build a glassmorphic container decoration with golden border in dark mode.
  BoxDecoration glassDecoration({BorderRadius? borderRadius}) {
    return BoxDecoration(
      color: glassColor,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: glassShadows,
      backgroundBlendMode: BlendMode.overlay,
    );
  }
}
