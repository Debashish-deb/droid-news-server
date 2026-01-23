import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_provider.dart' show AppThemeMode;

/// Provider for ThemeNotifier
/// Must be overridden in ProviderScope with actual SharedPreferences instance
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  throw UnimplementedError('themeProvider must be overridden in ProviderScope');
});

/// Provider for current theme mode
final currentThemeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(themeProvider).mode;
});

/// Provider for Flutter's ThemeMode
final flutterThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider).themeMode;
});

/// Provider for dark mode check
/// Handles System theme by checking actual platform brightness
final isDarkModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(currentThemeModeProvider);

  // Handle explicit dark modes
  if (mode == AppThemeMode.dark ||
      mode == AppThemeMode.amoled ||
      mode == AppThemeMode.bangladesh) {
    return true;
  }

  // Handle System theme by checking platform brightness
  if (mode == AppThemeMode.system) {
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  // AppThemeMode.light
  return false;
});

/// Provider for reader line height
final readerLineHeightProvider = Provider<double>((ref) {
  return ref.watch(themeProvider).readerLineHeight;
});

/// Provider for reader contrast
final readerContrastProvider = Provider<double>((ref) {
  return ref.watch(themeProvider).readerContrast;
});

/// Provider for glass color based on theme
final glassColorProvider = Provider((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  switch (mode) {
    case AppThemeMode.amoled:
      return Colors.black.withOpacity(0.65);
    case AppThemeMode.dark:
      return Colors.black.withOpacity(0.38);
    case AppThemeMode.bangladesh:
      return const Color(0xFF00392C).withOpacity(0.38);
    case AppThemeMode.light:
      return Colors.white.withOpacity(0.65);
    case AppThemeMode.system:
      return Colors.white.withOpacity(0.42);
  }
});

/// Provider for glass shadows based on theme
final glassShadowsProvider = Provider<List<BoxShadow>>((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  final shadowOpacity = switch (mode) {
    AppThemeMode.light => 0.14,
    AppThemeMode.dark => 0.25,
    AppThemeMode.amoled => 0.40,
    AppThemeMode.bangladesh => 0.22,
    _ => 0.10,
  };

  return <BoxShadow>[
    BoxShadow(
      color: Colors.black.withOpacity(shadowOpacity),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.white.withOpacity(0.03),
      blurRadius: 2,
      offset: const Offset(0, -1),
    ),
  ];
});

/// Provider for border color based on theme
final borderColorProvider = Provider<Color>((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  switch (mode) {
    case AppThemeMode.light:
      return Colors.grey.shade300;
    case AppThemeMode.dark:
      return Colors.grey.shade700;
    case AppThemeMode.amoled:
      return Colors.grey.shade800;
    case AppThemeMode.bangladesh:
      return const Color(0xFFFFD700);
    case AppThemeMode.system:
      return Colors.grey.shade400;
  }
});

/// Theme state immutable class
class ThemeState {
  const ThemeState({
    required this.mode,
    this.readerLineHeight = 1.6,
    this.readerContrast = 1.0,
  });
  final AppThemeMode mode;
  final double readerLineHeight;
  final double readerContrast;

  ThemeMode get themeMode {
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

  ThemeState copyWith({
    AppThemeMode? mode,
    double? readerLineHeight,
    double? readerContrast,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      readerLineHeight: readerLineHeight ?? this.readerLineHeight,
      readerContrast: readerContrast ?? this.readerContrast,
    );
  }
}

/// ThemeNotifier manages theme state
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier(this._prefs)
    : super(const ThemeState(mode: AppThemeMode.system)) {
    _loadFromPrefs();
  }
  final SharedPreferences _prefs;

  void _loadFromPrefs() {
    final themeName = _prefs.getString('theme') ?? 'system';
    final mode = AppThemeMode.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => AppThemeMode.system,
    );
    final lineHeight = _prefs.getDouble('reader_line_height') ?? 1.6;
    final contrast = _prefs.getDouble('reader_contrast') ?? 1.0;

    state = ThemeState(
      mode: mode,
      readerLineHeight: lineHeight,
      readerContrast: contrast,
    );
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _prefs.setString('theme', mode.name);
  }

  Future<void> setReaderLineHeight(double height) async {
    state = state.copyWith(readerLineHeight: height);
    await _prefs.setDouble('reader_line_height', height);
  }

  Future<void> setReaderContrast(double contrast) async {
    state = state.copyWith(readerContrast: contrast);
    await _prefs.setDouble('reader_contrast', contrast);
  }
}
