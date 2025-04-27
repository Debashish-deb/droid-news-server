import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'languageCode';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  LanguageProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString(_languageKey);
    if (storedCode != null && storedCode != _locale.languageCode) {
      _locale = Locale(storedCode);
      notifyListeners();
    }
  }

  Future<void> setLocale(String code) async {
    if (code == _locale.languageCode) return;
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
    notifyListeners();
  }

  Future<void> resetLocale() async {
    _locale = const Locale('en');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageKey);
    notifyListeners();
  }
}
