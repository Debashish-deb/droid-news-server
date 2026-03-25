import 'package:flutter/material.dart' show ThemeData, ThemeMode, Brightness;
import '../core/enums/theme_mode.dart';
import '../core/theme/theme.dart';

final _darkThemeCache = <AppThemeMode, ThemeData>{};

// resolveThemeData has two dimensions (mode + brightness for system mode), so
// we use a String compound key: "${mode.name}:${brightness.index}".
final _themeDataCache = <String, ThemeData>{};

@pragma('vm:prefer-inline')
ThemeMode resolveThemeMode(AppThemeMode mode) {
  switch (normalizeThemeMode(mode)) {
    case AppThemeMode.amoled:
      return ThemeMode.dark;
    case AppThemeMode.bangladesh:
      return ThemeMode.dark;
    case AppThemeMode.system:
    case AppThemeMode.light:
    case AppThemeMode.dark:
      return ThemeMode.system;
  }
}

/// Returns the dark-variant [ThemeData] for [mode].
///
/// The result is cached by mode so the exact same object identity is returned
/// on repeated calls, keeping `select()` stable and preventing false rebuilds.
@pragma('vm:prefer-inline')
ThemeData resolveDarkTheme(AppThemeMode mode) {
  final normalized = normalizeThemeMode(mode);
  return _darkThemeCache.putIfAbsent(normalized, () {
    switch (normalized) {
      case AppThemeMode.bangladesh:
        return AppTheme.bangladeshTheme;
      case AppThemeMode.system:
      case AppThemeMode.light:
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        return AppTheme.amoledTheme;
    }
  });
}

/// Returns the fully-resolved [ThemeData] for [mode] given [systemBrightness].
///
/// For [AppThemeMode.system] the result depends on both inputs; all other
/// modes ignore brightness.  Results are cached with a compound string key so
/// the same object identity is always returned for the same inputs.
@pragma('vm:prefer-inline')
ThemeData resolveThemeData(AppThemeMode mode, Brightness systemBrightness) {
  final normalized = normalizeThemeMode(mode);
  // Compound key — encoding brightness unconditionally keeps the logic
  // branch-free.  At most 10 entries ever (5 modes × 2 brightness values).
  final key = '${normalized.name}:${systemBrightness.index}';

  return _themeDataCache.putIfAbsent(key, () {
    switch (normalized) {
      case AppThemeMode.amoled:
        return AppTheme.amoledTheme;
      case AppThemeMode.bangladesh:
        return AppTheme.bangladeshTheme;
      case AppThemeMode.system:
      case AppThemeMode.light:
      case AppThemeMode.dark:
        return systemBrightness == Brightness.dark
            ? AppTheme.amoledTheme
            : AppTheme.lightTheme;
    }
  });
}

/// Short string label for [mode], useful for analytics, asset-path segments,
/// and debug logging without exposing the internal enum name.
///
/// Returns one of: `'light'` | `'dark'` | `'amoled'` | `'desh'` | `'system'`
@pragma('vm:prefer-inline')
String themeModeLabel(AppThemeMode mode) {
  switch (normalizeThemeMode(mode)) {
    case AppThemeMode.amoled:
      return 'amoled';
    case AppThemeMode.bangladesh:
      return 'desh';
    case AppThemeMode.system:
    case AppThemeMode.light:
    case AppThemeMode.dark:
      return 'system';
  }
}

/// Clears internal ThemeData caches.
///
/// Only required in unit tests or after a hot-reload of [AppTheme] statics.
/// Must never be called in production code.
void clearThemeCache() {
  _darkThemeCache.clear();
  _themeDataCache.clear();
}
