import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import "../../application/sync/sync_orchestrator.dart";
import '../../domain/repositories/settings_repository.dart' show SettingsRepository;
import '../../core/di/providers.dart' as di;

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
  LanguageNotifier(this._repository, this._syncOrchestrator)
    : super(const LanguageState(locale: Locale('en'))) {
    _syncOrchestrator.registerLanguageNotifier(this);
  }
  final SettingsRepository _repository;
  final SyncOrchestrator _syncOrchestrator;
  
  /// Public getter to avoid protected 'state' access warnings
  LanguageState get current => state;

  Future<void> initialize() async {
    final result = await _repository.getLanguageCode();
    final code = result.getOrElse('en');
    state = LanguageState(locale: Locale(code));
  }

  Future<void> setLanguage(String languageCode) async {
    if (state.languageCode == languageCode) return;

    final newLocale = Locale(languageCode);
    state = LanguageState(locale: newLocale);
    await _repository.setLanguageCode(languageCode);

    _syncOrchestrator.pushSettings();
  }

  Future<void> toggleLanguage() async {
    final newCode = state.isBengali ? 'en' : 'bn';
    await setLanguage(newCode);
  }

  Future<void> reload() async {
    await initialize();
  }
}

/// Provider for language state
final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) {
    final repo = ref.watch(di.settingsRepositoryProvider);
    final syncOrchestrator = ref.watch(di.syncOrchestratorProvider);
    return LanguageNotifier(repo, syncOrchestrator);
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
