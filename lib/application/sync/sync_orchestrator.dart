// lib/application/sync/sync_orchestrator.dart
// Central orchestrator for all cloud sync operations
// Provides real-time listeners, debouncing, and conflict resolution

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/providers/language_providers.dart' show LanguageNotifier;
import '../../infrastructure/sync/sync_service.dart';
import '../../core/premium_service.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../core/enums/theme_mode.dart'; 
import '../../presentation/providers/app_settings_providers.dart'; 
import '../lifecycle/app_state_machine.dart' show AppLifecycleNotifier;
import '../background/background_task_scheduler.dart';
import 'sync_tasks.dart'; 

class SyncOrchestrator {
  factory SyncOrchestrator() => _instance;
  SyncOrchestrator._internal();
  static final SyncOrchestrator _instance = SyncOrchestrator._internal();

  late final SyncService _syncService;
  late final PremiumService _premiumService;
  late final SharedPreferences _prefs;

  ThemeNotifier? _themeNotifier; 
  LanguageNotifier? _languageNotifier;
  AppSettingsNotifier? _appSettingsNotifier; 
  
  bool _initialized = false;
  bool _listeningToRealtime = false;

  StreamSubscription<Map<String, dynamic>?>? _settingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _favoritesSubscription;

  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(seconds: 2);

  DateTime? _lastSettingsPush;


  Future<void> init(
    SyncService syncService,
    PremiumService premiumService,
    SharedPreferences prefs,
  ) async {
    if (_initialized) return;
    _syncService = syncService;
    _premiumService = premiumService;
    _prefs = prefs;
    _initialized = true;
    debugPrint('🔄 SyncOrchestrator initialized');
  }

  void connectProviders({
    required ThemeNotifier themeNotifier,
    required LanguageNotifier languageNotifier,
    required AppSettingsNotifier appSettingsNotifier,
  }) {
    _themeNotifier = themeNotifier;
    _languageNotifier = languageNotifier;
    _appSettingsNotifier = appSettingsNotifier;
    debugPrint('🔗 SyncOrchestrator connected to providers');
  }

  void registerThemeNotifier(ThemeNotifier notifier) {
    _themeNotifier = notifier;
    debugPrint('🔗 SyncOrchestrator: ThemeNotifier registered');
  }
  
  void registerLanguageNotifier(LanguageNotifier notifier) {
    _languageNotifier = notifier;
    debugPrint('🔗 SyncOrchestrator: LanguageNotifier registered');
  }

  void registerAppSettingsNotifier(AppSettingsNotifier notifier) {
    _appSettingsNotifier = notifier;
    debugPrint('🔗 SyncOrchestrator: AppSettingsNotifier registered');
  }

  AppLifecycleNotifier? _appLifecycleNotifier;

  void registerAppLifecycleNotifier(AppLifecycleNotifier notifier) {
    _appLifecycleNotifier = notifier;
    debugPrint('🔗 SyncOrchestrator: AppLifecycleNotifier registered');
  }



  Future<void> pushAll() async {
    if (!_initialized || !_premiumService.isPremium) return;

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

  Future<void> pushSettings() async {
    if (!_initialized || !_premiumService.isPremium) return;

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

      BackgroundTaskScheduler().schedule(
        SyncSettingsTask(
          syncService: _syncService,
          settingsData: settingsData,
        ),
      );
    });
  }


  Future<void> pullAll() async {
    if (!_initialized || !_premiumService.isPremium) return;

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
    if (!_initialized || !_premiumService.isPremium) return;

    final Map<String, dynamic>? data = await _syncService.pullSettings();
    if (data == null) return;

    await _applySettings(data);
  }


  Timer? _batchTimer;
  Map<String, dynamic> _pendingSettingsUpdates = {};

  void startRealtimeSync() {
    if (!_initialized || !_premiumService.isPremium || _listeningToRealtime) {
      return;
    }

    debugPrint('🔴 Starting real-time sync listeners');

    bool started = false;
    final settingsStream = _syncService.settingsStream();
    if (settingsStream != null) {
      _settingsSubscription = settingsStream.listen((
        Map<String, dynamic>? data,
      ) {
        if (data == null) return;
        if (_lastSettingsPush != null &&
            DateTime.now().difference(_lastSettingsPush!) <
                const Duration(seconds: 5)) {
          return;
        }

        _pendingSettingsUpdates.addAll(data);

        _batchTimer?.cancel();
        _batchTimer = Timer(const Duration(milliseconds: 500), () {
          if (_pendingSettingsUpdates.isNotEmpty) {
            debugPrint('📡 Received settings update from another device');
            _applySettings(_pendingSettingsUpdates);
            _pendingSettingsUpdates = {};
          }
        });
      });
      started = true;
    }

    _listeningToRealtime = started;
    if (!started) {
      debugPrint('⚠️ Real-time sync unavailable (settings stream is null)');
    }
  }

  void stopRealtimeSync() {
    _settingsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    _settingsSubscription = null;
    _favoritesSubscription = null;
    _listeningToRealtime = false;
    debugPrint('🔴 Stopped real-time sync listeners');
  }


  Future<void> _applySettings(Map<String, dynamic> data) async {
    bool changed = false;

    if (data.containsKey('themeMode')) {
      final int cloudTheme = data['themeMode'] as int;
      final int localTheme = _themeNotifier?.current.mode.index ?? 0;
      if (cloudTheme != localTheme && cloudTheme < AppThemeMode.values.length) {
        await _themeNotifier?.setTheme(AppThemeMode.values[cloudTheme]);
        changed = true;
        debugPrint(
          '🎨 Theme synced from cloud: ${AppThemeMode.values[cloudTheme]}',
        );
      }
    }

    if (data.containsKey('languageCode')) {
      final String cloudLang = data['languageCode'] as String;
      final String localLang = _languageNotifier?.current.languageCode ?? 'en';
      if (cloudLang != localLang) {
        await _languageNotifier?.setLanguage(cloudLang);
        changed = true;
        debugPrint('🌐 Language synced from cloud: $cloudLang');
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

    if (data.containsKey('readerLineHeight') ||
        data.containsKey('readerContrast')) {
      final dynamic lineHeightRaw = data['readerLineHeight'];
      final dynamic contrastRaw = data['readerContrast'];
      final double? lineHeight =
          lineHeightRaw is num ? lineHeightRaw.toDouble() : null;
      final double? contrast =
          contrastRaw is num ? contrastRaw.toDouble() : null;
      await _themeNotifier?.updateReaderPrefs(
        lineHeight: lineHeight,
        contrast: contrast,
      );
      changed = true;
    }

    if (changed) {
      debugPrint('☁️ Applied settings from cloud');
    }
  }


  void dispose() {
    stopRealtimeSync();
    _debounceTimer?.cancel();
    _batchTimer?.cancel(); 
  }
}
