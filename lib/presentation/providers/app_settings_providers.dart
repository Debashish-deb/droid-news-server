// lib/presentation/providers/app_settings_providers.dart
// =======================================================
// RIVERPOD PROVIDERS FOR APP SETTINGS
// =======================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sync_service.dart';
import '../../core/unified_sync_manager.dart';
import 'shared_providers.dart';

// ============================================
// APP SETTINGS STATE
// ============================================

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

// ============================================
// APP SETTINGS NOTIFIER
// ============================================

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier(this._prefs, this._syncService)
    : super(const AppSettingsState()) {
    _loadFromPrefs();
  }
  final SharedPreferences _prefs;
  final SyncService _syncService;

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
    UnifiedSyncManager().pushSettings();
  }

  /// Set push notifications
  void setPushNotif(bool value) {
    state = state.copyWith(pushNotif: value);
    _prefs.setBool('push_notif', value);
    UnifiedSyncManager().pushSettings();
  }

  /// Reload from preferences
  void reload() {
    _loadFromPrefs();
  }
}

// ============================================
// PROVIDERS
// ============================================

/// Main app settings provider
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return AppSettingsNotifier(prefs, SyncService());
    });

/// Convenience: data saver mode
final dataSaverProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider.select((state) => state.dataSaver));
});

/// Convenience: push notifications enabled
final pushNotifProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider.select((state) => state.pushNotif));
});
