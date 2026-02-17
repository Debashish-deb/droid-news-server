// lib/application/sync/sync_orchestrator.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/providers/language_providers.dart' show LanguageNotifier;
import '../../infrastructure/sync/sync_service.dart';
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
  SyncOrchestrator(
    this._syncService,
    this._premiumRepository,
    this._prefs,
  ) : _initialized = true {
    debugPrint('🔄 SyncOrchestrator initialized with Repository pattern');
  }

  final SyncService _syncService;
  final PremiumRepository _premiumRepository;
  final SharedPreferences _prefs;

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

  /// Registers UI Notifiers for state propagation
  void connectProviders({
    required ThemeNotifier themeNotifier,
    required LanguageNotifier languageNotifier,
    required AppSettingsNotifier appSettingsNotifier,
  }) {
    _themeNotifier = themeNotifier;
    _languageNotifier = languageNotifier;
    _appSettingsNotifier = appSettingsNotifier;
    debugPrint('🔗 SyncOrchestrator connected to UI providers');
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

  /// Pushes all syncable data to the cloud (Premium Only)
  Future<void> pushAll() async {
    if (!_initialized || !_premiumRepository.isPremium) return;

    _appLifecycleNotifier?.startSync();
    try {
      await Future.wait([
        pushSettings(),
      ]);
      _appLifecycleNotifier?.endSync();
    } catch (e) {
      debugPrint('❌ Sync Push Error: $e');
      _appLifecycleNotifier?.endSync(success: false);
    }
  }

  /// Pushes settings with debouncing to prevent excessive API calls
  Future<void> pushSettings() async {
    if (!_initialized || !_premiumRepository.isPremium) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      _lastSettingsPush = DateTime.now();
      
      final settingsData = {
        'dataSaver': _appSettingsNotifier?.current.dataSaver ?? _prefs.getBool('data_saver') ?? false,
        'pushNotif': _appSettingsNotifier?.current.pushNotif ?? _prefs.getBool('push_notif') ?? true,
        'themeMode': _themeNotifier?.current.mode.index ?? _prefs.getInt('theme_mode') ?? 0,
        'languageCode': _languageNotifier?.current.languageCode ?? _prefs.getString('languageCode') ?? 'en',
        'readerLineHeight': _themeNotifier?.current.readerLineHeight ?? _prefs.getDouble('reader_line_height') ?? 1.6,
        'readerContrast': _themeNotifier?.current.readerContrast ?? _prefs.getDouble('reader_contrast') ?? 1.0,
      };

      // Offload actual network work to the task scheduler
      BackgroundTaskScheduler().schedule(
        SyncSettingsTask(
          syncService: _syncService,
          settingsData: settingsData,
        ),
      );
    });
  }

  /// Force-pulls latest data from cloud
  Future<void> pullAll() async {
    if (!_initialized || !_premiumRepository.isPremium) return;

    _appLifecycleNotifier?.startSync();
    try {
      await Future.wait([
        pullSettings(),
      ]);
      _appLifecycleNotifier?.endSync();
    } catch (e) {
      debugPrint('❌ Sync Pull Error: $e');
      _appLifecycleNotifier?.endSync(success: false);
    }
  }

  Future<void> pullSettings() async {
    if (!_initialized || !_premiumRepository.isPremium) return;

    final Map<String, dynamic>? data = await _syncService.pullSettings();
    if (data == null) return;

    await _applySettings(data);
  }

  /// Starts listening for real-time Firestore updates
  void startRealtimeSync() {
    if (!_initialized || !_premiumRepository.isPremium || _listeningToRealtime) {
      return;
    }

    debugPrint('📡 Starting real-time sync listeners');

    final settingsStream = _syncService.settingsStream();
    if (settingsStream != null) {
      _settingsSubscription = settingsStream.listen((Map<String, dynamic>? data) {
        if (data == null) return;
        
        // Anti-Feedback Loop: Ignore updates if we just pushed our own settings
        if (_lastSettingsPush != null &&
            DateTime.now().difference(_lastSettingsPush!) < const Duration(seconds: 5)) {
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
    bool changed = false;

    if (data.containsKey('themeMode')) {
      final int cloudTheme = data['themeMode'] as int;
      final int localTheme = _themeNotifier?.current.mode.index ?? 0;
      if (cloudTheme != localTheme && cloudTheme < AppThemeMode.values.length) {
        await _themeNotifier?.setTheme(AppThemeMode.values[cloudTheme]);
        changed = true;
      }
    }

    if (data.containsKey('languageCode')) {
      final String cloudLang = data['languageCode'] as String;
      final String localLang = _languageNotifier?.current.languageCode ?? 'en';
      if (cloudLang != localLang) {
        await _languageNotifier?.setLanguage(cloudLang);
        changed = true;
      }
    }

    if (data.containsKey('dataSaver')) {
      final bool cloudDataSaver = data['dataSaver'] as bool;
      if (cloudDataSaver != (_appSettingsNotifier?.current.dataSaver ?? false)) {
        _appSettingsNotifier?.setDataSaver(cloudDataSaver);
        changed = true;
      }
    }

    if (data.containsKey('pushNotif')) {
      final bool cloudPushNotif = data['pushNotif'] as bool;
      if (cloudPushNotif != (_appSettingsNotifier?.current.pushNotif ?? true)) {
        _appSettingsNotifier?.setPushNotif(cloudPushNotif);
        changed = true;
      }
    }

    if (data.containsKey('readerLineHeight') || data.containsKey('readerContrast')) {
      await _themeNotifier?.updateReaderPrefs(
        lineHeight: (data['readerLineHeight'] as num?)?.toDouble(),
        contrast: (data['readerContrast'] as num?)?.toDouble(),
      );
      changed = true;
    }

    if (changed) {
      debugPrint('☁️ Applied updated settings from cloud');
    }
  }

  void dispose() {
    stopRealtimeSync();
    _debounceTimer?.cancel();
    _batchTimer?.cancel(); 
  }
}