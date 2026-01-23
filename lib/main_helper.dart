// Helper method to convert AppThemeMode to ThemeMode
import 'package:flutter/material.dart' show ThemeMode;

import 'core/theme_provider.dart' show AppThemeMode;

ThemeMode _getThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
    case AppThemeMode.amoled:
    case AppThemeMode.bangladesh:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}
