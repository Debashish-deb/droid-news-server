import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'unified_sync_manager.dart';

class LanguageProvider extends ChangeNotifier {
  LanguageProvider() {
    _loadLocale();
  }
  static const String _languageKey = 'languageCode';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> _loadLocale() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storedCode = prefs.getString(_languageKey);

    if (storedCode != null) {
      _locale = Locale(storedCode);
    } else {
      // Try to detect system locale
      final Locale systemLocale =
          WidgetsBinding.instance.platformDispatcher.locale;
      if (<String>['en', 'bn'].contains(systemLocale.languageCode)) {
        _locale = Locale(systemLocale.languageCode);
      } else {
        _locale = const Locale('en'); // fallback
      }
    }

    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    if (code == _locale.languageCode) return;
    _locale = Locale(code);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
    notifyListeners();
    // Sync to cloud
    UnifiedSyncManager().pushSettings();
  }

  Future<void> resetLocale() async {
    _locale = const Locale('en');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageKey);
    notifyListeners();
  }
}
