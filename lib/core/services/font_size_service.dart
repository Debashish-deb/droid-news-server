import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Font size preference service
class FontSizeService {
  static const String _fontSizeKey = 'font_size_preference';

  /// Available font sizes
  static const Map<String, double> fontSizes = {
    'small': 0.85,
    'medium': 1.0,
    'large': 1.15,
    'extra_large': 1.30,
  };

  /// Get current font size multiplier
  static Future<double> getFontSizeMultiplier() async {
    final prefs = await SharedPreferences.getInstance();
    final sizeKey = prefs.getString(_fontSizeKey) ?? 'medium';
    return fontSizes[sizeKey] ?? 1.0;
  }

  /// Set font size preference
  static Future<void> setFontSize(String sizeKey) async {
    if (!fontSizes.containsKey(sizeKey)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeKey, sizeKey);
  }

  /// Get current font size key
  static Future<String> getCurrentFontSizeKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontSizeKey) ?? 'medium';
  }
}

/// Font size notifier for state management
class FontSizeNotifier extends ChangeNotifier {

  FontSizeNotifier() {
    _loadFontSize();
  }
  double _multiplier = 1.0;
  String _currentKey = 'medium';

  double get multiplier => _multiplier;
  String get currentKey => _currentKey;

  Future<void> _loadFontSize() async {
    _multiplier = await FontSizeService.getFontSizeMultiplier();
    _currentKey = await FontSizeService.getCurrentFontSizeKey();
    notifyListeners();
  }

  Future<void> setFontSize(String sizeKey) async {
    if (!FontSizeService.fontSizes.containsKey(sizeKey)) return;

    _multiplier = FontSizeService.fontSizes[sizeKey]!;
    _currentKey = sizeKey;
    await FontSizeService.setFontSize(sizeKey);
    notifyListeners();
  }

  /// Get scaled text style
  TextStyle scale(TextStyle base) {
    return base.copyWith(fontSize: (base.fontSize ?? 14) * _multiplier);
  }
}

/// Extension for easy font scaling
extension FontSizeExtension on TextStyle {
  /// Scale font size based on user preference
  TextStyle scaled(double multiplier) {
    return copyWith(fontSize: (fontSize ?? 14) * multiplier);
  }
}
