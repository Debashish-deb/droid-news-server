// lib/application/sync/sync_orchestrator.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/providers/language_providers.dart'
    show LanguageNotifier;
import '../../infrastructure/sync/services/sync_service.dart';
import '../../domain/repositories/premium_repository.dart'; // Updated
import '../../presentation/providers/theme_providers.dart';
import '../../core/enums/theme_mode.dart';
import '../../presentation/providers/app_settings_providers.dart';
import '../lifecycle/app_state_machine.dart' show AppLifecycleNotifier;
import '../background/background_task_scheduler.dart';
import 'sync_tasks.dart';

/// Central orchestrator for all cloud sync operations.
///
/// Refactored to use [PremiumRepository] and [get_it] DI.

class SyncOrchestrator {
  SyncOrchestrator(this._syncService, this._prefs) : _initialized = true;

  SyncOrchestrator.disabled(this._prefs)
    : _syncService = null,
      _initialized = false;

  final SyncService? _syncService;
  final SharedPreferences? _prefs;

  ThemeNotifier? _themeNotifier;
  LanguageNotifier? _languageNotifier;
  AppSettingsNotifier? _appSettingsNotifier;
  AppLifecycleNotifier? _appLifecycleNotifier;

  final bool _initialized;
  bool _listeningToRealtime = false;

  StreamSubscription<Map<String, dynamic>?>? _settingsSubscription;

  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(seconds: 2);

  DateTime? _lastSettingsPush;
  Timer? _batchTimer;
  Map<String, dynamic> _pendingSettingsUpdates = {};

  bool get _canRunBasicSync => _initialized && _syncService != null;

  /// Registers UI Notifiers for state propagation
  void connectProviders({
    required ThemeNotifier themeNotifier,
    required LanguageNotifier languageNotifier,
    required AppSettingsNotifier appSettingsNotifier,
  }) {
    _themeNotifier = themeNotifier;
    _languageNotifier = languageNotifier;
    _appSettingsNotifier = appSettingsNotifier;
  }

  void registerAppLifecycleNotifier(AppLifecycleNotifier notifier) {
    _appLifecycleNotifier = notifier;
  }

  void registerThemeNotifier(ThemeNotifier notifier) {
    _themeNotifier = notifier;
  }

  void registerAppSettingsNotifier(AppSettingsNotifier notifier) {
    _appSettingsNotifier = notifier;
  }

  void registerLanguageNotifier(LanguageNotifier notifier) {
    _languageNotifier = notifier;
  }

  /// Pull settings immediately after auth/entitlement becomes available.
  Future<void> syncSettingsAfterAuth() async {
    if (!_canRunBasicSync) return;
    await pullSettings();
    startRealtimeSync();
  }

  /// Pushes all syncable data to the cloud (Premium Only)
  Future<void> pushAll() async {
    if (!_canRunBasicSync) return;

    _appLifecycleNotifier?.startSync();
    try {
      await Future.wait([pushSettings(immediate: true)]);
      _appLifecycleNotifier?.endSync();
    } catch (e) {
      debugPrint('❌ Sync Push Error: $e');
      _appLifecycleNotifier?.endSync(success: false);
    }
  }

  /// Pushes settings with debouncing to prevent excessive API calls
  Future<void> pushSettings({bool immediate = false}) async {
    final prefs = _prefs;
    if (!_canRunBasicSync || prefs == null) return;

    // 1. Calculate and save local update timestamp IMMEDIATELY
    // This prevents race conditions where pullSettings might run before the push completes
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('sync_local_updated_at', nowMs);

    void executePush() {
      _lastSettingsPush = DateTime.now();

      final settingsData = {
        'dataSaver':
            _appSettingsNotifier?.current.dataSaver ??
            prefs.getBool('data_saver') ??
            false,
        'pushNotif':
            _appSettingsNotifier?.current.pushNotif ??
            prefs.getBool('push_notif') ??
            true,
        'themeMode':
            _themeNotifier?.current.mode.index ??
            _resolveThemeModeIndexFromPrefs(),
        'languageCode':
            _languageNotifier?.current.languageCode ??
            prefs.getString('language_code') ??
            prefs.getString('languageCode') ??
            'en',
        'readerLineHeight':
            _themeNotifier?.current.readerLineHeight ??
            prefs.getDouble('reader_line_height') ??
            1.6,
        'readerContrast':
            _themeNotifier?.current.readerContrast ??
            prefs.getDouble('reader_contrast') ??
            1.0,
        // Pass the pre-calculated timestamp to ensure consistency
        'clientUpdatedAtMs': nowMs,
      };

      final syncService = _syncService;
      if (syncService == null) return;

      BackgroundTaskScheduler().schedule(
        SyncSettingsTask(syncService: syncService, settingsData: settingsData),
      );
    }

    _debounceTimer?.cancel();

    if (immediate) {
      executePush();
      return;
    }

    _debounceTimer = Timer(_debounceDuration, executePush);
  }

  /// Force-pulls latest data from cloud
  Future<void> pullAll() async {
    if (!_canRunBasicSync) return;

    _appLifecycleNotifier?.startSync();
    try {
      await Future.wait([pullSettings()]);
      _appLifecycleNotifier?.endSync();
    } catch (e) {
      debugPrint('❌ Sync Pull Error: $e');
      _appLifecycleNotifier?.endSync(success: false);
    }
  }

  Future<void> pullSettings() async {
    if (!_canRunBasicSync) return;

    final Map<String, dynamic>? data = await _syncService?.pullSettings();
    if (data == null) return;

    await _applySettings(data);
  }

  /// Starts listening for real-time Firestore updates
  void startRealtimeSync() {
    if (!_canRunBasicSync || _listeningToRealtime) {
      return;
    }

    debugPrint('📡 Starting real-time sync listeners');

    final settingsStream = _syncService?.settingsStream();
    if (settingsStream != null) {
      _settingsSubscription = settingsStream.listen((
        Map<String, dynamic>? data,
      ) {
        if (data == null) return;

        // Anti-Feedback Loop: Ignore updates if we just pushed our own settings
        final lastPush = _lastSettingsPush;
        if (lastPush != null &&
            DateTime.now().difference(lastPush) < const Duration(seconds: 5)) {
          return;
        }

        _pendingSettingsUpdates.addAll(data);

        // Batch incoming updates to prevent UI jitter
        _batchTimer?.cancel();
        _batchTimer = Timer(const Duration(milliseconds: 500), () {
          if (_pendingSettingsUpdates.isNotEmpty) {
            _applySettings(_pendingSettingsUpdates);
            _pendingSettingsUpdates = {};
          }
        });
      });
      _listeningToRealtime = true;
    }
  }

  void stopRealtimeSync() {
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    _listeningToRealtime = false;
    debugPrint('🛑 Stopped real-time sync listeners');
  }

  /// Internal helper to propagate cloud data to the local UI state
  Future<void> _applySettings(Map<String, dynamic> data) async {
    final int localTs = _prefs?.getInt('sync_local_updated_at') ?? 0;

    // Robustly parse cloud timestamp (Firestore can return num, int, or String)
    final dynamic rawCloudTs = data['clientUpdatedAtMs'];
    final int cloudTs = switch (rawCloudTs) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    // Only apply if cloud data is strictly newer.
    // Use <= to prevent overwriting local state with redundant cloud data
    // which might trigger unnecessary state transitions and resets.
    if (cloudTs <= localTs && localTs != 0) {
      debugPrint(
        '☁️ Skipping stale/redundant cloud settings (Cloud: $cloudTs <= Local: $localTs)',
      );
      return;
    }

    debugPrint(
      '☁️ Applying cloud settings (Cloud: $cloudTs > Local: $localTs)',
    );

    // Update local watermark if we accepted cloud data
    if (cloudTs > localTs) {
      _prefs?.setInt('sync_local_updated_at', cloudTs);
    }

    bool changed = false;

    if (data.containsKey('themeMode')) {
      final dynamic rawTheme = data['themeMode'];
      final int? cloudTheme = switch (rawTheme) {
        final int v => v,
        final num v => v.toInt(),
        final String v => int.tryParse(v),
        _ => null,
      };
      if (cloudTheme == null ||
          cloudTheme < 0 ||
          cloudTheme >= AppThemeMode.values.length) {
        debugPrint('⚠️ Ignoring invalid cloud themeMode: $rawTheme');
      } else {
        final cloudMode = themeModeFromIndex(cloudTheme);
        final localMode = normalizeThemeMode(
          _themeNotifier?.current.mode ?? AppThemeMode.system,
        );
        if (cloudMode != localMode) {
          debugPrint(
            'SyncOrchestrator: Cloud theme mode (${cloudMode.name}) differs from local (${localMode.name}). Applying cloud theme.',
          );
          await _themeNotifier?.setTheme(cloudMode, syncToCloud: false);
          changed = true;
        }
      }
    }

    if (data.containsKey('languageCode')) {
      final String? rawLang = data['languageCode']?.toString().toLowerCase();
      final String? cloudLang = switch (rawLang) {
        'bn' => 'bn',
        'en' => 'en',
        _ => null,
      };
      if (cloudLang == null) {
        debugPrint(
          '⚠️ Ignoring invalid cloud languageCode: ${data['languageCode']}',
        );
      } else {
        final String localLang =
            _languageNotifier?.current.languageCode ?? 'en';
        if (cloudLang != localLang) {
          await _languageNotifier?.setLanguage(cloudLang, syncToCloud: false);
          changed = true;
        }
      }
    }

    if (data.containsKey('dataSaver')) {
      final bool cloudDataSaver = data['dataSaver'] as bool;
      if (cloudDataSaver !=
          (_appSettingsNotifier?.current.dataSaver ?? false)) {
        _appSettingsNotifier?.setDataSaver(cloudDataSaver, syncToCloud: false);
        changed = true;
      }
    }

    if (data.containsKey('pushNotif')) {
      final bool cloudPushNotif = data['pushNotif'] as bool;
      if (cloudPushNotif != (_appSettingsNotifier?.current.pushNotif ?? true)) {
        _appSettingsNotifier?.setPushNotif(cloudPushNotif, syncToCloud: false);
        changed = true;
      }
    }

    if (data.containsKey('readerLineHeight') ||
        data.containsKey('readerContrast')) {
      await _themeNotifier?.updateReaderPrefs(
        lineHeight: (data['readerLineHeight'] as num?)?.toDouble(),
        contrast: (data['readerContrast'] as num?)?.toDouble(),
        syncToCloud: false,
      );
      changed = true;
    }

    if (changed) {
      debugPrint('☁️ Applied updated settings from cloud');
    }
  }

  int _resolveThemeModeIndexFromPrefs() {
    if (_prefs == null) return AppThemeMode.system.index;

    // 1. Try 'theme' string key (used by SettingsRepositoryImpl)
    final themeName = _prefs.getString('theme');
    if (themeName != null) {
      return themeModeFromName(themeName).index;
    }

    // 2. Try 'theme_mode' int key (legacy or internal)
    final themeMode = _prefs.getInt('theme_mode');
    if (themeMode != null) {
      return themeModeFromIndex(themeMode).index;
    }

    // 3. Last resort: default to system
    return AppThemeMode.system.index;
  }

  void dispose() {
    stopRealtimeSync();
    _debounceTimer?.cancel();
    _batchTimer?.cancel();
  }
}
