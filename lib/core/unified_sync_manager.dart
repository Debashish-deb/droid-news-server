// lib/core/unified_sync_manager.dart
// Central orchestrator for all cloud sync operations
// Provides real-time listeners, debouncing, and conflict resolution

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_service.dart';
import 'premium_service.dart';
import 'theme_provider.dart';
import 'language_provider.dart';
import 'app_settings_service.dart';

class UnifiedSyncManager {
  factory UnifiedSyncManager() => _instance;
  UnifiedSyncManager._internal();
  // Singleton
  static final UnifiedSyncManager _instance = UnifiedSyncManager._internal();

  // Dependencies (set via init)
  late final SyncService _syncService;
  late final PremiumService _premiumService;
  late final SharedPreferences _prefs;

  // Providers to update on remote changes (set via connect)
  ThemeProvider? _themeProvider;
  LanguageProvider? _languageProvider;
  AppSettingsService? _appSettingsService;
  // FavoritesManager removed - now using Riverpod favoritesProvider

  bool _initialized = false;
  bool _listeningToRealtime = false;

  // Real-time stream subscriptions
  StreamSubscription<Map<String, dynamic>?>? _settingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _favoritesSubscription;

  // Debounce timer to prevent rapid cloud writes
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(seconds: 2);

  // Track last sync times to avoid loops
  DateTime? _lastSettingsPush;
  DateTime? _lastFavoritesPush;

  // ─────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────

  /// Initialize with core dependencies
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
    debugPrint('🔄 UnifiedSyncManager initialized');
  }

  /// Connect providers for two-way sync
  void connectProviders({
    required ThemeProvider theme,
    required LanguageProvider language,
    required AppSettingsService appSettings,
    // favorites parameter removed - using Riverpod instead
  }) {
    _themeProvider = theme;
    _languageProvider = language;
    _appSettingsService = appSettings;
    // _favoritesManager removed - favorites synced via Riverpod provider
    debugPrint('🔗 UnifiedSyncManager connected to providers');
  }

  // ─────────────────────────────────────────────
  // PUSH ALL (Local → Cloud)
  // ─────────────────────────────────────────────

  /// Push all local data to cloud
  Future<void> pushAll() async {
    if (!_initialized || !_premiumService.isPremium) return;

    await Future.wait([
      pushSettings(),
      // pushFavorites(), // Now handled by Riverpod FavoritesNotifier,
    ]);
  }

  /// Push settings to cloud (debounced)
  Future<void> pushSettings() async {
    if (!_initialized || !_premiumService.isPremium) return;

    // Debounce rapid changes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      _lastSettingsPush = DateTime.now();
      await _syncService.pushSettings(
        dataSaver:
            _appSettingsService?.dataSaver ??
            _prefs.getBool('data_saver') ??
            false,
        pushNotif:
            _appSettingsService?.pushNotif ??
            _prefs.getBool('push_notif') ??
            true,
        themeMode:
            _themeProvider?.appThemeMode.index ??
            _prefs.getInt('theme_mode') ??
            0,
        languageCode:
            _languageProvider?.locale.languageCode ??
            _prefs.getString('languageCode') ??
            'en',
        readerLineHeight:
            _themeProvider?.readerLineHeight ??
            _prefs.getDouble('reader_line_height') ??
            1.6,
        readerContrast:
            _themeProvider?.readerContrast ??
            _prefs.getDouble('reader_contrast') ??
            1.0,
      );
    });
  }

  /// Push favorites to cloud (merged with server data)
  /// NOW HANDLED BY RIVERPOD FavoritesNotifier
  // Future<void> // pushFavorites(), // Now handled by Riverpod FavoritesNotifier async {
  //   if (!_initialized || !_premiumService.isPremium) return;
  //   _lastFavoritesPush = DateTime.now();
  //   // Favorites sync handled by Riverpod FavoritesNotifier.syncToCloud()
  // }

  // ─────────────────────────────────────────────
  // PULL ALL (Cloud → Local)
  // ─────────────────────────────────────────────

  /// Pull all data from cloud and apply locally
  Future<void> pullAll() async {
    if (!_initialized || !_premiumService.isPremium) return;

    await Future.wait([
      pullSettings(),
      // pullFavorites(), // Now handled by Riverpod FavoritesNotifier,
    ]);
  }

  /// Pull settings from cloud and apply locally
  Future<void> pullSettings() async {
    if (!_initialized || !_premiumService.isPremium) return;

    final Map<String, dynamic>? data = await _syncService.pullSettings();
    if (data == null) return;

    await _applySettings(data);
  }

  /// Pull favorites from cloud and merge locally
  // Future<void> // pullFavorites(), // Now handled by Riverpod FavoritesNotifier async {
  //   if (!_initialized || !_premiumService.isPremium) return;

  //   // FavoritesManager handles its own cloud merge
  //   await _favoritesManager?.syncFromCloud();
  // }

  // ─────────────────────────────────────────────
  // REAL-TIME LISTENERS
  // ─────────────────────────────────────────────

  // Batch pending updates to reduce rebuilds
  Timer? _batchTimer;
  Map<String, dynamic> _pendingSettingsUpdates = {};
  // bool _pendingFavoritesUpdate = false; // Favorites realtime sync handled by Riverpod FavoritesNotifier

  /// Start listening to real-time Firestore changes
  void startRealtimeSync() {
    if (!_initialized || !_premiumService.isPremium || _listeningToRealtime) {
      return;
    }

    debugPrint('🔴 Starting real-time sync listeners');

    // Listen to settings changes
    final settingsStream = _syncService.settingsStream();
    if (settingsStream != null) {
      _settingsSubscription = settingsStream.listen((
        Map<String, dynamic>? data,
      ) {
        if (data == null) return;
        // Avoid applying our own changes (within 5 seconds of push)
        if (_lastSettingsPush != null &&
            DateTime.now().difference(_lastSettingsPush!) <
                const Duration(seconds: 5)) {
          return;
        }

        // BATCH: Don't process immediately
        _pendingSettingsUpdates.addAll(data);

        // Process batch after 500ms
        _batchTimer?.cancel();
        _batchTimer = Timer(const Duration(milliseconds: 500), () {
          if (_pendingSettingsUpdates.isNotEmpty) {
            debugPrint('📡 Received settings update from another device');
            _applySettings(_pendingSettingsUpdates);
            _pendingSettingsUpdates = {};
          }
        });
      });
    }

    // Listen to favorites changes
    // final favoritesStream = _syncService.favoritesStream();
    // if (favoritesStream != null) {
    //   _favoritesSubscription = favoritesStream.listen((Map<String, dynamic>? data) {
    //     if (data == null) return;
    //     // Avoid applying our own changes
    //     if (_lastFavoritesPush != null &&
    //         DateTime.now().difference(_lastFavoritesPush!) < const Duration(seconds: 5)) {
    //       return;
    //     }

    //     // BATCH: Mark for update
    //     _pendingFavoritesUpdate = true;

    //     // Process batch after 500ms
    //     _batchTimer?.cancel();
    //     _batchTimer = Timer(const Duration(milliseconds: 500), () {
    //       if (_pendingFavoritesUpdate) {
    //         debugPrint('📡 Received favorites update from another device');
    //         _favoritesManager?.syncFromCloud();
    //         _pendingFavoritesUpdate = false;
    //       }
    //     });
    //   });
    // }
    // Favorites realtime sync handled by Riverpod FavoritesNotifier

    _listeningToRealtime = true;
  }

  /// Stop real-time listeners
  void stopRealtimeSync() {
    _settingsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    _settingsSubscription = null;
    _favoritesSubscription = null;
    _listeningToRealtime = false;
    debugPrint('🔴 Stopped real-time sync listeners');
  }

  // ─────────────────────────────────────────────
  // APPLY SETTINGS LOCALLY
  // ─────────────────────────────────────────────

  Future<void> _applySettings(Map<String, dynamic> data) async {
    bool changed = false;

    // Theme
    if (data.containsKey('themeMode')) {
      final int cloudTheme = data['themeMode'] as int;
      final int localTheme = _themeProvider?.appThemeMode.index ?? 0;
      if (cloudTheme != localTheme && cloudTheme < AppThemeMode.values.length) {
        await _themeProvider?.toggleTheme(AppThemeMode.values[cloudTheme]);
        changed = true;
        debugPrint(
          '🎨 Theme synced from cloud: ${AppThemeMode.values[cloudTheme]}',
        );
      }
    }

    // Language
    if (data.containsKey('languageCode')) {
      final String cloudLang = data['languageCode'] as String;
      final String localLang = _languageProvider?.locale.languageCode ?? 'en';
      if (cloudLang != localLang) {
        await _languageProvider?.setLocale(cloudLang);
        changed = true;
        debugPrint('🌐 Language synced from cloud: $cloudLang');
      }
    }

    // Data Saver
    if (data.containsKey('dataSaver')) {
      final bool cloudDataSaver = data['dataSaver'] as bool;
      if (cloudDataSaver != _appSettingsService?.dataSaver) {
        _appSettingsService?.setDataSaver(cloudDataSaver);
        changed = true;
      }
    }

    // Push notifications
    if (data.containsKey('pushNotif')) {
      final bool cloudPushNotif = data['pushNotif'] as bool;
      if (cloudPushNotif != _appSettingsService?.pushNotif) {
        _appSettingsService?.setPushNotif(cloudPushNotif);
        changed = true;
      }
    }

    // Reader preferences
    if (data.containsKey('readerLineHeight') ||
        data.containsKey('readerContrast')) {
      await _themeProvider?.updateReaderPrefs(
        lineHeight: data['readerLineHeight'] as double?,
        contrast: data['readerContrast'] as double?,
      );
      changed = true;
    }

    if (changed) {
      debugPrint('☁️ Applied settings from cloud');
    }
  }

  // ─────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────

  void dispose() {
    stopRealtimeSync();
    _debounceTimer?.cancel();
    _batchTimer?.cancel(); // Clean up batch timer
  }
}
