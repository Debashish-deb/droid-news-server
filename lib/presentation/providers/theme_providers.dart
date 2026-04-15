import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/identity/entitlement_policy.dart';
import '../../application/sync/sync_orchestrator.dart';
import '../../domain/entities/subscription.dart' show SubscriptionTier;
import '../../domain/repositories/premium_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../core/enums/theme_mode.dart';
import '../../core/di/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/theme_skeleton.dart';

const double _defaultReaderLineHeight = 1.6;
const double _defaultReaderContrast = 1.0;

/// Shared non-color layout/shape tokens for all themes.
final themeSkeletonProvider = Provider<ThemeSkeleton>((ref) {
  return ThemeSkeleton.shared;
});

/// Theme-owned color combination. This is the only theme-varying UI bundle;
/// all structural metrics stay in [themeSkeletonProvider].
final themeColorCombinationProvider = Provider<AppThemeColorCombination>((ref) {
  final mode = normalizeThemeMode(ref.watch(currentThemeModeProvider));
  final systemBrightness =
      SchedulerBinding.instance.platformDispatcher.platformBrightness;
  return AppTheme.colorCombinationForMode(
    mode,
    systemBrightness: systemBrightness,
  );
});

@pragma('vm:prefer-inline')
ThemeMode _toFlutterThemeMode(AppThemeMode mode) {
  switch (normalizeThemeMode(mode)) {
    case AppThemeMode.dark:
    case AppThemeMode.bangladesh:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}

@pragma('vm:prefer-inline')
bool _isDarkThemeMode(AppThemeMode mode) {
  final normalized = normalizeThemeMode(mode);
  return normalized == AppThemeMode.dark ||
      normalized == AppThemeMode.bangladesh;
}

// Provider for ThemeNotifier
// Must be overridden in ProviderScope with actual SharedPreferences instance
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final syncOrchestrator = ref.read(syncOrchestratorProvider);
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
  return ref.watch(
    themeColorCombinationProvider.select((palette) => palette.glassColor),
  );
});

// Provider for glass shadows based on theme
final glassShadowsProvider = Provider<List<BoxShadow>>((ref) {
  final skeleton = ref.watch(themeSkeletonProvider);
  final shadowColor = ref.watch(
    themeColorCombinationProvider.select((palette) => palette.glassShadowColor),
  );

  return <BoxShadow>[
    BoxShadow(
      color: shadowColor,
      blurRadius: skeleton.glassShadowBlurRadius,
      spreadRadius: skeleton.glassShadowSpreadRadius,
      offset: Offset(0, skeleton.glassShadowOffsetY),
    ),
  ];
});

// Provider for border color based on theme
final borderColorProvider = Provider<Color>((ref) {
  return ref.watch(
    themeColorCombinationProvider.select((palette) => palette.borderColor),
  );
});

/// Single source of truth for selection accent used across screens.
/// Kept intentionally high-contrast for theme consistency.
final selectionColorProvider = Provider<Color>((ref) {
  return ref.watch(
    themeColorCombinationProvider.select((palette) => palette.selectionColor),
  );
});

// Provider for navigation icon color
final navIconColorProvider = Provider<Color>((ref) {
  return ref.watch(selectionColorProvider);
});

// Provider for navigation indicator color
final navIndicatorColorProvider = Provider<Color>((ref) {
  return ref.watch(
    themeColorCombinationProvider.select(
      (palette) => palette.navIndicatorColor,
    ),
  );
});

final textColorProvider = Provider<Color>((ref) {
  return ref.watch(
    themeColorCombinationProvider.select((palette) => palette.textColor),
  );
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
        final isPremiumTheme = !EntitlementPolicy.canUseTheme(
          SubscriptionTier.free,
          state.mode,
        );
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
  int _themePersistGeneration = 0;

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
    if (!EntitlementPolicy.canUseTheme(
      _premiumRepository.tier,
      normalizedMode,
    )) {
      if (!EntitlementPolicy.canUseTheme(_premiumRepository.tier, state.mode)) {
        state = state.copyWith(mode: AppThemeMode.system);
        _scheduleThemePersist(AppThemeMode.system, syncToCloud: syncToCloud);
      }
      return;
    }
    if (normalizedMode == state.mode) return;
    state = state.copyWith(mode: normalizedMode);
    _scheduleThemePersist(normalizedMode, syncToCloud: syncToCloud);
  }

  void _scheduleThemePersist(AppThemeMode mode, {bool syncToCloud = true}) {
    final generation = ++_themePersistGeneration;
    unawaited(
      _persistThemeDeferred(
        mode,
        generation: generation,
        syncToCloud: syncToCloud,
      ),
    );
  }

  Future<void> _persistThemeDeferred(
    AppThemeMode mode, {
    required int generation,
    bool syncToCloud = true,
  }) async {
    // Keep theme transition jank-free: defer disk + sync churn and coalesce
    // rapid taps to persist only the most recent selection.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || generation != _themePersistGeneration) return;

    await _repository.setThemeMode(mode);
    if (syncToCloud) {
      // Push cloud sync after the visual theme swap settles.
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted || generation != _themePersistGeneration) return;
      _syncOrchestrator.pushSettings();
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
