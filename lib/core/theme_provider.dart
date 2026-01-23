import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'unified_sync_manager.dart';

/// Available app theme modes.
enum AppThemeMode { system, light, dark, bangladesh, amoled }

/// Key for SharedPreferences.
const String _kThemeModeKey = 'theme_mode';

/// Theme controller + glass + reader + system helpers
class ThemeProvider with ChangeNotifier {
  ThemeProvider(this._prefs) {
    _loadThemeMode();
    _loadReaderPrefs();
  }

  final SharedPreferences _prefs;

  AppThemeMode _currentTheme = AppThemeMode.light; // Default to light theme

  // ======================
  // READER PREFERENCES
  // ======================

  static const String _kLineHeightKey = 'reader_line_height';
  static const String _kContrastKey = 'reader_contrast';

  double _readerLineHeight = 1.6;
  double _readerContrast = 1.0;

  double get readerLineHeight => _readerLineHeight;
  double get readerContrast => _readerContrast;

  // ======================
  // GETTERS
  // ======================

  AppThemeMode get appThemeMode => _currentTheme;

  /// Converts custom [AppThemeMode] to Flutter [ThemeMode].
  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
      case AppThemeMode.bangladesh:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  // ======================
  // LOAD / SAVE
  // ======================

  void _loadThemeMode() {
    final int? stored = _prefs.getInt(_kThemeModeKey);
    if (stored != null && stored >= 0 && stored < AppThemeMode.values.length) {
      _currentTheme = AppThemeMode.values[stored];
    }
    // If no stored theme, keep the default (light)
  }

  /// Reload theme from preferences and notify listeners
  Future<void> reloadTheme() async {
    _loadThemeMode();
    notifyListeners();
  }

  void _loadReaderPrefs() {
    _readerLineHeight = _prefs.getDouble(_kLineHeightKey) ?? 1.6;
    _readerContrast = _prefs.getDouble(_kContrastKey) ?? 1.0;
  }

  Future<void> toggleTheme(AppThemeMode mode) async {
    if (_currentTheme == mode) return;
    _currentTheme = mode;
    notifyListeners();
    await _prefs.setInt(_kThemeModeKey, mode.index);
    // Sync to cloud
    UnifiedSyncManager().pushSettings();
  }

  Future<void> updateReaderPrefs({double? lineHeight, double? contrast}) async {
    if (lineHeight != null) {
      _readerLineHeight = lineHeight;
      await _prefs.setDouble(_kLineHeightKey, lineHeight);
    }
    if (contrast != null) {
      _readerContrast = contrast;
      await _prefs.setDouble(_kContrastKey, contrast);
    }
    notifyListeners();
    // Sync to cloud
    UnifiedSyncManager().pushSettings();
  }

  // ======================
  // GLASS COLORS (SYSTEM)
  // ======================

  Color get glassColor {
    switch (_currentTheme) {
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
  }

  /// Premium border logic
  Color get borderColor {
    switch (_currentTheme) {
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
      case AppThemeMode.bangladesh:
        return const Color(0xFFFFD700);
      case AppThemeMode.light:
        return Colors.grey.withOpacity(
          0.5,
        ); // Increased from 0.3 for visibility
      case AppThemeMode.system:
        return Colors.grey.withOpacity(
          0.4,
        ); // Better visibility for system mode
    }
  }

  // ======================
  // SHADOW / DEPTH MODEL
  // ======================

  double get shadowOpacity => switch (_currentTheme) {
    AppThemeMode.amoled => 0.08,
    AppThemeMode.dark => 0.12,
    AppThemeMode.bangladesh => 0.14,
    _ => 0.10,
  };

  List<BoxShadow> get glassShadows => <BoxShadow>[
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

  // ======================
  // TEXT EFFECTS (READER SAFE)
  // ======================

  TextStyle floatingTextStyle({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
  }) {
    final Color base = color ?? (isDarkMode ? Colors.white : Colors.black87);

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: _readerLineHeight,
      color: _applyContrast(base),
      shadows: <Shadow>[
        if (isDarkMode) Shadow(color: base.withOpacity(0.35), blurRadius: 10),
        Shadow(color: base.withOpacity(0.12), blurRadius: 4),
      ],
    );
  }

  Color _applyContrast(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * _readerContrast).clamp(0.0, 1.0))
        .toColor();
  }

  // ======================
  // DECORATIONS
  // ======================

  BoxDecoration glassDecoration({
    BorderRadius radius = const BorderRadius.all(Radius.circular(16)),
  }) {
    return BoxDecoration(
      color: glassColor,
      borderRadius: radius,
      border: Border.all(
        color: borderColor,
        width: (_currentTheme == AppThemeMode.light) ? 1 : 1.6,
      ),
      boxShadow: glassShadows,
      backgroundBlendMode: BlendMode.overlay,
    );
  }

  // ======================
  // SYSTEM HELPERS
  // ======================

  void lightHaptic() {
    if (isDarkMode) {
      HapticFeedback.lightImpact();
    }
  }

  bool get isDarkMode =>
      _currentTheme == AppThemeMode.dark ||
      _currentTheme == AppThemeMode.amoled ||
      _currentTheme == AppThemeMode.bangladesh;

  bool get isAMOLED => _currentTheme == AppThemeMode.amoled;

  bool get isBangladesh => _currentTheme == AppThemeMode.bangladesh;
}
