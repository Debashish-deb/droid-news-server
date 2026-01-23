import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/unified_sync_manager.dart';
import 'shared_providers.dart';

// ============================================================================
// Language State Management
// ============================================================================

/// Language state
class LanguageState {
  const LanguageState({required this.locale});
  final Locale locale;

  LanguageState copyWith({Locale? locale}) {
    return LanguageState(locale: locale ?? this.locale);
  }

  String get languageCode => locale.languageCode;
  bool get isBengali => locale.languageCode == 'bn';
  bool get isEnglish => locale.languageCode == 'en';
}

/// Language Notifier - manages language state
class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier(this._prefs)
    : super(const LanguageState(locale: Locale('en'))) {
    _loadLanguage();
  }
  final SharedPreferences _prefs;
  static const String _kLanguageKey = 'language_code';

  void _loadLanguage() {
    final String? stored = _prefs.getString(_kLanguageKey);
    final locale = stored != null ? Locale(stored) : const Locale('en');
    state = LanguageState(locale: locale);
  }

  Future<void> setLanguage(String languageCode) async {
    if (state.languageCode == languageCode) return;

    final newLocale = Locale(languageCode);
    state = LanguageState(locale: newLocale);
    await _prefs.setString(_kLanguageKey, languageCode);

    // Sync to cloud
    UnifiedSyncManager().pushSettings();
  }

  Future<void> toggleLanguage() async {
    final newCode = state.isBengali ? 'en' : 'bn';
    await setLanguage(newCode);
  }

  Future<void> reload() async {
    _loadLanguage();
  }
}

/// Provider for language state
final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    return LanguageNotifier(prefs);
  },
);

// ============================================================================
// Convenience Providers
// ============================================================================

/// Provides just the current locale
final currentLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(languageProvider.select((state) => state.locale));
});

/// Provides just the language code
final languageCodeProvider = Provider<String>((ref) {
  return ref.watch(languageProvider.select((state) => state.languageCode));
});

/// Provides Bengali status
final isBengaliProvider = Provider<bool>((ref) {
  return ref.watch(languageProvider.select((state) => state.isBengali));
});
