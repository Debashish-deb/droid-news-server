import 'package:flutter/material.dart' show ThemeData, ThemeMode, Brightness;
import 'core/enums/theme_mode.dart';
import 'core/theme.dart';

/// Resolve the [ThemeMode] for the app-level setting.
ThemeMode resolveThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return ThemeMode.system;
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
    case AppThemeMode.amoled:
    case AppThemeMode.bangladesh:
      return ThemeMode.dark;
  }
}

/// Resolve the appropriate dark theme variant for the current mode.
ThemeData resolveDarkTheme(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.amoled:
      return AppTheme.amoledTheme;
    case AppThemeMode.bangladesh:
      return AppTheme.bangladeshTheme;
    case AppThemeMode.dark:
      return AppTheme.darkTheme;
    case AppThemeMode.light:
    case AppThemeMode.system:
      return AppTheme.darkTheme;
  }
}

/// Resolve the concrete theme data for an explicit mode.
ThemeData resolveThemeData(AppThemeMode mode, Brightness systemBrightness) {
  switch (mode) {
    case AppThemeMode.light:
      return AppTheme.lightTheme;
    case AppThemeMode.dark:
      return AppTheme.darkTheme;
    case AppThemeMode.amoled:
      return AppTheme.amoledTheme;
    case AppThemeMode.bangladesh:
      return AppTheme.bangladeshTheme;
    case AppThemeMode.system:
      return systemBrightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme;
  }
}
