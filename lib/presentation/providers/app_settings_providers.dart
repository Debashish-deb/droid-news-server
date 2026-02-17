// lib/presentation/providers/app_settings_providers.dart
// =======================================================
// RIVERPOD PROVIDERS FOR APP SETTINGS
// =======================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import "../../application/sync/sync_orchestrator.dart";
import '../../infrastructure/repositories/favorites_repository_impl.dart' show FavoritesRepositoryImpl;
import '../../infrastructure/sync/sync_service.dart' show SyncService;
import '../../core/di/providers.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../infrastructure/repositories/settings_repository_impl.dart';
import '../../domain/repositories/search_repository.dart';
import '../../infrastructure/repositories/search_repository_impl.dart';
import '../../domain/repositories/favorites_repository.dart';


@immutable
class AppSettingsState {
  const AppSettingsState({this.dataSaver = false, this.pushNotif = true});
  final bool dataSaver;
  final bool pushNotif;

  AppSettingsState copyWith({bool? dataSaver, bool? pushNotif}) {
    return AppSettingsState(
      dataSaver: dataSaver ?? this.dataSaver,
      pushNotif: pushNotif ?? this.pushNotif,
    );
  }
}


class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier(this._prefs, this._syncService, this._syncOrchestrator)
    : super(const AppSettingsState()) {
    _loadFromPrefs();
    _syncOrchestrator.registerAppSettingsNotifier(this);
  }
  final SharedPreferences _prefs;
  final SyncService _syncService;
  final SyncOrchestrator _syncOrchestrator;
  
  /// Public getter to avoid protected 'state' access warnings
  AppSettingsState get current => state;

  void _loadFromPrefs() {
    final dataSaver = _prefs.getBool('data_saver') ?? false;
    final pushNotif = _prefs.getBool('push_notif') ?? true;
    state = AppSettingsState(dataSaver: dataSaver, pushNotif: pushNotif);
  }

  /// Sync settings from cloud
  Future<void> syncFromCloud() async {
    final cloudData = await _syncService.pullSettings();
    if (cloudData == null) return;

    bool changed = false;
    bool newDataSaver = state.dataSaver;
    bool newPushNotif = state.pushNotif;

    if (cloudData.containsKey('dataSaver') &&
        cloudData['dataSaver'] != state.dataSaver) {
      newDataSaver = cloudData['dataSaver'] as bool;
      await _prefs.setBool('data_saver', newDataSaver);
      changed = true;
    }

    if (cloudData.containsKey('pushNotif') &&
        cloudData['pushNotif'] != state.pushNotif) {
      newPushNotif = cloudData['pushNotif'] as bool;
      await _prefs.setBool('push_notif', newPushNotif);
      changed = true;
    }

    if (changed) {
      state = AppSettingsState(
        dataSaver: newDataSaver,
        pushNotif: newPushNotif,
      );
    }
  }

  /// Set data saver mode
  void setDataSaver(bool value) {
    state = state.copyWith(dataSaver: value);
    _prefs.setBool('data_saver', value);
    _syncOrchestrator.pushSettings();
  }

  
  void setPushNotif(bool value) {
    state = state.copyWith(pushNotif: value);
    _prefs.setBool('push_notif', value);
    _syncOrchestrator.pushSettings();
  }

  /// Reload from preferences
  void reload() {
    _loadFromPrefs();
  }
}


/// Main app settings provider
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final syncService = ref.watch(syncServiceProvider);
      final syncOrchestrator = ref.watch(syncOrchestratorProvider);
      return AppSettingsNotifier(prefs, syncService, syncOrchestrator);
    });

/// Settings Repository provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(prefs);
});

/// Search Repository provider
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final newsRepo = ref.watch(newsRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return SearchRepositoryImpl(newsRepo, settingsRepo);
});

/// Favorites Repository provider
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final syncService = ref.watch(syncServiceProvider);
  final db = ref.watch(appDatabaseProvider);
  return FavoritesRepositoryImpl(prefs, syncService, db);
});

/// Convenience: data saver mode
final dataSaverProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider.select((state) => state.dataSaver));
});

/// Convenience: push notifications enabled
final pushNotifProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider.select((state) => state.pushNotif));
});
