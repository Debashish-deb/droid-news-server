import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

enum AppThemeMode { system, light, dark, bangladesh }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get appThemeMode => _mode;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.bangladesh:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }

  ThemeData get lightTheme => AppTheme.buildLightTheme();

  ThemeData get darkTheme =>
      _mode == AppThemeMode.bangladesh
          ? AppTheme.buildBangladeshTheme()
          : AppTheme.buildDarkTheme();

  ThemeProvider() {
    _loadThemePreference();
  }

  void toggleTheme(AppThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _saveThemePreference();
    notifyListeners();
  }

  void setSystemTheme() => toggleTheme(AppThemeMode.system);

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme_mode');
    switch (saved) {
      case 'light':
        _mode = AppThemeMode.light;
        break;
      case 'dark':
        _mode = AppThemeMode.dark;
        break;
      case 'bangladesh':
        _mode = AppThemeMode.bangladesh;
        break;
      default:
        _mode = AppThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', _mode.name);
  }
}
