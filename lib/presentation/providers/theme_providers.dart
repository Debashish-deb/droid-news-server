import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sync/sync_orchestrator.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../core/enums/theme_mode.dart';
import '../../core/di/providers.dart';
import '../../core/theme/design_tokens.dart';

const double _defaultReaderLineHeight = 1.6;
const double _defaultReaderContrast = 1.0;

@pragma('vm:prefer-inline')
ThemeMode _toFlutterThemeMode(AppThemeMode mode) {
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

@pragma('vm:prefer-inline')
bool _isDarkThemeMode(AppThemeMode mode) {
  final normalized = normalizeThemeMode(mode);
  return normalized == AppThemeMode.bangladesh ||
      normalized == AppThemeMode.amoled;
}

// Provider for ThemeNotifier
// Must be overridden in ProviderScope with actual SharedPreferences instance
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final syncOrchestrator = ref.watch(syncOrchestratorProvider);
  final premiumRepository = ref.watch(premiumRepositoryProvider);
  return ThemeNotifier(repo, syncOrchestrator, premiumRepository);
});

// Provider for current theme mode
final currentThemeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(themeProvider.select((s) => s.mode));
});

// Provider for Flutter's ThemeMode
final flutterThemeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(currentThemeModeProvider);
  return _toFlutterThemeMode(mode);
});

// Provider for dark mode check
// Handles System theme by checking actual platform brightness
final isDarkModeProvider = Provider<bool>((ref) {
  final mode = normalizeThemeMode(ref.watch(currentThemeModeProvider));

  if (_isDarkThemeMode(mode)) {
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
  return ref.watch(themeProvider.select((s) => s.readerLineHeight));
});

// Provider for reader contrast
final readerContrastProvider = Provider<double>((ref) {
  return ref.watch(themeProvider.select((s) => s.readerContrast));
});

// Provider for glass color based on theme
final glassColorProvider = Provider<Color>((ref) {
  final mode = normalizeThemeMode(ref.watch(currentThemeModeProvider));
  final isDark = ref.watch(isDarkModeProvider);
  switch (mode) {
    case AppThemeMode.amoled:
      return Colors.black.withValues(alpha: 0.86);
    case AppThemeMode.bangladesh:
      return const Color(0xFF00392C).withValues(alpha: 0.6);
    case AppThemeMode.system:
      return isDark
          ? AppColors.darkSurface.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.8);
    case AppThemeMode.light:
    case AppThemeMode.dark:
      return isDark
          ? AppColors.darkSurface.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.8);
  }
});

// Provider for glass shadows based on theme
final glassShadowsProvider = Provider<List<BoxShadow>>((ref) {
  final mode = normalizeThemeMode(ref.watch(currentThemeModeProvider));
  final isDark = ref.watch(isDarkModeProvider);
  final shadowOpacity = switch (mode) {
    AppThemeMode.amoled => 0.34,
    AppThemeMode.bangladesh => 0.22,
    AppThemeMode.system => isDark ? 0.24 : 0.12,
    AppThemeMode.light => isDark ? 0.24 : 0.12,
    AppThemeMode.dark => isDark ? 0.24 : 0.12,
  };

  return <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: shadowOpacity),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.03),
      blurRadius: 2,
      offset: const Offset(0, -1),
    ),
  ];
});

// Provider for border color based on theme
final borderColorProvider = Provider<Color>((ref) {
  return ref.watch(isDarkModeProvider) ? Colors.white : Colors.black;
});

/// Single source of truth for selection accent used across screens.
/// Kept intentionally high-contrast for theme consistency.
final selectionColorProvider = Provider<Color>((ref) {
  return ref.watch(isDarkModeProvider) ? Colors.white : Colors.black;
});

// Provider for navigation icon color
final navIconColorProvider = Provider<Color>((ref) {
  return ref.watch(selectionColorProvider);
});

// Provider for navigation indicator color
final navIndicatorColorProvider = Provider<Color>((ref) {
  return ref.watch(selectionColorProvider).withValues(alpha: 0.18);
});

final textColorProvider = Provider<Color>((ref) {
  return ref.watch(isDarkModeProvider) ? Colors.white : Colors.black;
});

// Theme state immutable class
class ThemeState {
  const ThemeState({
    required this.mode,
    this.readerLineHeight = _defaultReaderLineHeight,
    this.readerContrast = _defaultReaderContrast,
  });
  final AppThemeMode mode;
  final double readerLineHeight;
  final double readerContrast;

  ThemeMode get themeMode {
    return _toFlutterThemeMode(mode);
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeState &&
        other.mode == mode &&
        other.readerLineHeight == readerLineHeight &&
        other.readerContrast == readerContrast;
  }

  @override
  int get hashCode => Object.hash(mode, readerLineHeight, readerContrast);
}

// ThemeNotifier manages theme state
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier(
    this._repository,
    this._syncOrchestrator,
    this._premiumRepository,
  ) : super(
        ThemeState(
          mode: normalizeThemeMode(_repository.getThemeModeSync()),
          readerLineHeight: _repository.getReaderLineHeightSync(),
          readerContrast: _repository.getReaderContrastSync(),
        ),
      ) {
    _syncOrchestrator.registerThemeNotifier(this);

    // Reactive listener for premium status changes
    _premiumStatusSub = _premiumRepository.premiumStatusStream.listen((
      isPremium,
    ) {
      if (!isPremium) {
        final isPremiumTheme =
            normalizeThemeMode(state.mode) == AppThemeMode.bangladesh;
        if (isPremiumTheme) {
          // Only downgrade if the server has DEFINITIVELY resolved status.
          // During startup, status may flip false before Firestore responds.
          final shouldReset =
              _premiumRepository.isStatusResolved &&
              !_premiumRepository.isPremium;
          if (shouldReset) {
            unawaited(setTheme(AppThemeMode.system));
          }
        }
      }
    });
  }
  final SettingsRepository _repository;
  final SyncOrchestrator _syncOrchestrator;
  final PremiumRepository _premiumRepository;
  StreamSubscription<bool>? _premiumStatusSub;

  /// Public getter to avoid protected 'state' access warnings
  ThemeState get current => state;

  void initializeSync() {
    // Note: In SettingsRepositoryImpl, these are currently Future but
    // we can try to get them from prefs synchronously if the implementation allows.
    // For now, we use defaults if not immediately available, or refactor repository.
    // However, if the repository is already initialized with _prefs,
    // we can add a sync version there too.

    // For this optimization, we'll assume a fallback to system and then let
    // the async initialize() update it if needed, OR we can add sync methods.

    // UPDATED: Assuming we add sync methods to repository below.
    final mode = normalizeThemeMode(_repository.getThemeModeSync());
    final height = _repository.getReaderLineHeightSync();
    final contrast = _repository.getReaderContrastSync();

    state = ThemeState(
      mode: mode,
      readerLineHeight: height,
      readerContrast: contrast,
    );
  }

  Future<void> initialize() async {
    final modeFuture = _repository.getThemeMode();
    final heightFuture = _repository.getReaderLineHeight();
    final contrastFuture = _repository.getReaderContrast();

    final modeResult = await modeFuture;
    final mode = normalizeThemeMode(
      modeResult.fold((l) => AppThemeMode.system, (r) => r),
    );

    final heightResult = await heightFuture;
    final height = heightResult.fold((l) => _defaultReaderLineHeight, (r) => r);

    final contrastResult = await contrastFuture;
    final contrast = contrastResult.fold(
      (l) => _defaultReaderContrast,
      (r) => r,
    );

    final nextState = ThemeState(
      mode: mode,
      readerLineHeight: height,
      readerContrast: contrast,
    );
    if (nextState == state) return;
    state = nextState;
  }

  Future<void> setTheme(AppThemeMode mode, {bool syncToCloud = true}) async {
    final normalizedMode = normalizeThemeMode(mode);
    if (normalizedMode == AppThemeMode.bangladesh &&
        _premiumRepository.shouldShowAds) {
      if (state.mode == AppThemeMode.bangladesh) {
        state = state.copyWith(mode: AppThemeMode.system);
        unawaited(_persistTheme(AppThemeMode.system, syncToCloud: syncToCloud));
      }
      return;
    }
    if (normalizedMode == state.mode) return;
    state = state.copyWith(mode: normalizedMode);
    unawaited(_persistTheme(normalizedMode, syncToCloud: syncToCloud));
  }

  Future<void> _persistTheme(
    AppThemeMode mode, {
    bool syncToCloud = true,
  }) async {
    await _repository.setThemeMode(mode);
    if (syncToCloud) {
      _syncOrchestrator.pushSettings(immediate: true);
    }
  }

  @override
  void dispose() {
    _premiumStatusSub?.cancel();
    super.dispose();
  }

  Future<void> setReaderLineHeight(double height) async {
    if (height == state.readerLineHeight) return;
    state = state.copyWith(readerLineHeight: height);
    await _repository.setReaderLineHeight(height);
    _syncOrchestrator.pushSettings();
  }

  Future<void> setReaderContrast(double contrast) async {
    if (contrast == state.readerContrast) return;
    state = state.copyWith(readerContrast: contrast);
    await _repository.setReaderContrast(contrast);
    _syncOrchestrator.pushSettings();
  }

  Future<void> updateReaderPrefs({
    double? lineHeight,
    double? contrast,
    bool syncToCloud = true,
  }) async {
    final nextLineHeight = lineHeight ?? state.readerLineHeight;
    final nextContrast = contrast ?? state.readerContrast;
    if (nextLineHeight == state.readerLineHeight &&
        nextContrast == state.readerContrast) {
      return;
    }

    state = state.copyWith(
      readerLineHeight: nextLineHeight,
      readerContrast: nextContrast,
    );

    final writes = <Future<void>>[];
    if (lineHeight != null) {
      writes.add(_repository.setReaderLineHeight(lineHeight));
    }
    if (contrast != null) {
      writes.add(_repository.setReaderContrast(contrast));
    }
    if (writes.isNotEmpty) {
      await Future.wait(writes);
    }

    if (syncToCloud) {
      _syncOrchestrator.pushSettings();
    }
  }
}

typedef FloatingTextStyleBuilder =
    TextStyle Function({double fontSize, FontWeight fontWeight, Color? color});

// Provider for floating text style builder (replacing legacy method)
final floatingTextStyleProvider = Provider<FloatingTextStyleBuilder>((ref) {
  final lineHeight = ref.watch(readerLineHeightProvider);
  final contrast = ref.watch(readerContrastProvider);
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
          .withLightness((hsl.lightness * contrast).clamp(0.0, 1.0))
          .toColor();
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: lineHeight,
      color: applyContrast(base),
      shadows: <Shadow>[
        if (isDark) Shadow(color: base.withValues(alpha: 0.35), blurRadius: 10),
        Shadow(color: base.withValues(alpha: 0.12), blurRadius: 4),
      ],
    );
  };
});
