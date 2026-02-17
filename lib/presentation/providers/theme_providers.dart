import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sync/sync_orchestrator.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../core/enums/theme_mode.dart';
import '../../core/di/providers.dart';
import '../../core/design_tokens.dart';

// Provider for ThemeNotifier
// Must be overridden in ProviderScope with actual SharedPreferences instance
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final syncOrchestrator = ref.watch(syncOrchestratorProvider);
  return ThemeNotifier(repo, syncOrchestrator);
});

// Provider for current theme mode
final currentThemeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(themeProvider).mode;
});

// Provider for Flutter's ThemeMode
final flutterThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider).themeMode;
});

// Provider for dark mode check
// Handles System theme by checking actual platform brightness
final isDarkModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(currentThemeModeProvider);

  if (mode == AppThemeMode.dark ||
      mode == AppThemeMode.amoled ||
      mode == AppThemeMode.bangladesh) {
    return true;
  }

  if (mode == AppThemeMode.system) {
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }


  return false;
});

// Provider for reader line height
final readerLineHeightProvider = Provider<double>((ref) {
  return ref.watch(themeProvider).readerLineHeight;
});

// Provider for reader contrast
final readerContrastProvider = Provider<double>((ref) {
  return ref.watch(themeProvider).readerContrast;
});

// Provider for glass color based on theme
final glassColorProvider = Provider<Color>((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  switch (mode) {
    case AppThemeMode.amoled:
      return Colors.black.withOpacity(0.85);
    case AppThemeMode.dark:
      return AppColors.darkSurface.withOpacity(0.7); 

    case AppThemeMode.bangladesh:
      return const Color(0xFF00392C).withOpacity(0.6);
    case AppThemeMode.light:
      return Colors.white.withOpacity(0.8);
    case AppThemeMode.system:
      return Colors.white.withOpacity(0.75);
  }
});

// Provider for glass shadows based on theme
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

// Provider for border color based on theme
final borderColorProvider = Provider<Color>((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  switch (mode) {
    case AppThemeMode.light:
      return Colors.blue; // User requested "panel border color same" as icons (Blue)
    case AppThemeMode.dark:
      return AppColors.gold.withOpacity(0.8); // Royal Gold with weight
    case AppThemeMode.amoled:
      return Colors.grey.shade800.withOpacity(0.5);
    case AppThemeMode.bangladesh:
      return const Color(0xFF006A4E).withOpacity(0.6); // Green
    case AppThemeMode.system:
      return Colors.blue;
  }
});

// Provider for navigation icon color
final navIconColorProvider = Provider<Color>((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  switch (mode) {
    case AppThemeMode.light:
    case AppThemeMode.system:
      return Colors.blue;
    case AppThemeMode.dark:
    case AppThemeMode.amoled:
      return AppColors.gold; // Royal Gold
    case AppThemeMode.bangladesh:
      return const Color(0xFFF42A41); // Bangladesh Red (for mix with Green border)
  }
});

// Provider for navigation indicator color
final navIndicatorColorProvider = Provider<Color>((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  switch (mode) {
    case AppThemeMode.light:
    case AppThemeMode.system:
      return Colors.blue.withOpacity(0.2);
    case AppThemeMode.dark:
    case AppThemeMode.amoled:
      return AppColors.gold.withOpacity(0.2);
    case AppThemeMode.bangladesh:
      return const Color(0xFFF42A41).withOpacity(0.2); // Bangladesh Red
  }
});

final textColorProvider = Provider<Color>((ref) {
  final mode = ref.read(themeProvider).mode;
  final isLight = mode == AppThemeMode.light;
  // If system, check platform brightness or simplify
  if (mode == AppThemeMode.system) {
     final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
     return brightness == Brightness.light ? Colors.black87 : Colors.white;
  }
  return isLight ? Colors.black87 : Colors.white;
});

// Theme state immutable class
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



// ThemeNotifier manages theme state
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier(this._repository, this._syncOrchestrator)
    : super(const ThemeState(mode: AppThemeMode.system)) {
    _syncOrchestrator.registerThemeNotifier(this);
  }
  final SettingsRepository _repository;
  final SyncOrchestrator _syncOrchestrator;
  
  /// Public getter to avoid protected 'state' access warnings
  ThemeState get current => state;

  Future<void> initialize() async {
    final modeResult = await _repository.getThemeMode();
    final mode = modeResult.fold((l) => AppThemeMode.system, (r) => r);
    
    final heightResult = await _repository.getReaderLineHeight();
    final height = heightResult.fold((l) => 1.6, (r) => r);
    
    final contrastResult = await _repository.getReaderContrast();
    final contrast = contrastResult.fold((l) => 1.0, (r) => r);

    state = ThemeState(
      mode: mode,
      readerLineHeight: height,
      readerContrast: contrast,
    );
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _repository.setThemeMode(mode);
    _syncOrchestrator.pushSettings();
  }

  Future<void> setReaderLineHeight(double height) async {
    state = state.copyWith(readerLineHeight: height);
    await _repository.setReaderLineHeight(height);
    _syncOrchestrator.pushSettings();
  }

  Future<void> setReaderContrast(double contrast) async {
    state = state.copyWith(readerContrast: contrast);
    await _repository.setReaderContrast(contrast);
    _syncOrchestrator.pushSettings();
  }

  Future<void> updateReaderPrefs({double? lineHeight, double? contrast}) async {
    state = state.copyWith(
      readerLineHeight: lineHeight ?? state.readerLineHeight,
      readerContrast: contrast ?? state.readerContrast,
    );
    if (lineHeight != null) await _repository.setReaderLineHeight(lineHeight);
    if (contrast != null) await _repository.setReaderContrast(contrast);
    
    _syncOrchestrator.pushSettings();
  }
}



typedef FloatingTextStyleBuilder = TextStyle Function({
  double fontSize,
  FontWeight fontWeight,
  Color? color,
});

// Provider for floating text style builder (replacing legacy method)
final floatingTextStyleProvider = Provider<FloatingTextStyleBuilder>((ref) {
  final state = ref.watch(themeProvider);
  final isDark = ref.watch(isDarkModeProvider);

  return ({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
  }) {
    final Color base = color ?? (isDark ? Colors.white : Colors.black87);

    Color applyContrast(Color c) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness * state.readerContrast).clamp(0.0, 1.0))
          .toColor();
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: state.readerLineHeight,
      color: applyContrast(base),
      shadows: <Shadow>[
        if (isDark) Shadow(color: base.withOpacity(0.35), blurRadius: 10),
        Shadow(color: base.withOpacity(0.12), blurRadius: 4),
      ],
    );
  };
});
