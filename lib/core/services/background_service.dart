import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../security/secure_prefs.dart';
import '../premium_service.dart';
import '../../infrastructure/services/remote_config_service.dart';
import '../../infrastructure/sync/sync_service.dart';
import '../telemetry/observability_service.dart';
import '../telemetry/structured_logger.dart';

/// Background service using WorkManager
class BackgroundService {
  static const String simpleTaskKey = 'simpleTask';
  static const String syncTaskKey = 'syncTask';

  /// Initialize WorkManager
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Register a periodic sync task
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      syncTaskKey,
      simpleTaskKey,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      initialDelay: const Duration(minutes: 5),
    );
  }

  /// Cancel all tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}

/// Top-level function for background execution.
/// Since this runs in a separate Isolate, no DI is available.
/// We must manually instantiate dependencies.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (kDebugMode) {
        print("🔄 [Background] Starting task: $task");
      }

      // 1. Initialize Flutter & Firebase
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Instantiate Base Dependencies
      final prefs = await SharedPreferences.getInstance();
      final securePrefs = SecurePrefs(); // Wraps FlutterSecureStorage
      final logger = StructuredLogger(); 
      final observability = ObservabilityService();
      
      // 3. Initialize Remote Config (Standard Singleton access works if we instantiated it)
      // However, RemoteConfigService is a singleton wrapper. 
      // We need to call initialize() on it if we want it to fetch.
      // But for background sync, we might just want the cached values or safe defaults (via hardcoded whitelist in PremiumService).
      final remoteConfig = RemoteConfigService(); 
      // Note: We avoid calling remoteConfig.initialize() here to prevent excessive background fetches
      // unless strictly necessary. PremiumService falls back gracefully.

      // 4. Instantiate PremiumService with manual injection
      final premium = PremiumService(
        prefs: prefs,
        injectedSecurePrefs: securePrefs,
        injectedRemoteConfig: remoteConfig,
      );
      // Ensure local status is loaded (from secure storage)
      await premium.loadStatus();

      // 5. Instantiate SyncService
      final syncService = SyncService(premium, observability, logger);

      // 6. Execute Task Logic
      switch (task) {
        case BackgroundService.simpleTaskKey:
        case BackgroundService.syncTaskKey:
          if (kDebugMode) print("🔄 [Background] Flushing pending sync data...");
          await syncService.flushPending();
          
          // Optionally pull updates if needed
          // await syncService.pullFavorites();
          // await syncService.pullSettings();
          
          if (kDebugMode) print("✅ [Background] Sync complete.");
          break;
      }

      return Future.value(true);
    } catch (e, stack) {
      if (kDebugMode) {
        print("🔴 [Background] Task failed: $e");
        print(stack);
      }
      return Future.value(false);
    }
  });
}
