// ignore_for_file: avoid_classes_with_only_static_members

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../infrastructure/persistence/notifications/notification_dedup_store.dart';

import '../../tools/firebase_options.dart';
import '../../infrastructure/repositories/premium_repository_impl.dart';
import '../architecture/either.dart' show Left, Right;
import '../security/secure_prefs.dart';
import '../../infrastructure/sync/services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../security/ssl_pinning.dart' show SSLPinning;
import '../telemetry/observability_service.dart';
import '../telemetry/structured_logger.dart';
import '../../platform/persistence/database_config.dart';
import '../../infrastructure/repositories/news_repository_impl.dart';
import '../../infrastructure/services/news/rss_service.dart';
import '../../infrastructure/network/app_network_service.dart';
import '../../infrastructure/services/ml/news_feed_category_classifier.dart';
import '../../platform/persistence/app_database.dart';
import '../security/ssl_pinning.dart';
import '../../infrastructure/services/notifications/push_notification_service.dart';

/// Background service using WorkManager
class BackgroundService {
  static const String simpleTaskKey = 'simpleTask';
  static const String syncTaskKey = 'syncTask';
  static Future<void>? _initializeFuture;
  static Future<void>? _registerPeriodicSyncFuture;

  /// Initialize WorkManager
  static Future<void> initialize() async {
    final pendingInitialize =
        _initializeFuture ??
        Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    _initializeFuture = pendingInitialize;

    try {
      await pendingInitialize;
    } catch (_) {
      if (identical(_initializeFuture, pendingInitialize)) {
        _initializeFuture = null;
      }
      rethrow;
    }
  }

  /// Register a periodic sync task
  static Future<void> registerPeriodicSync() async {
    final pendingRegister =
        _registerPeriodicSyncFuture ??
        () async {
          await initialize();
          await Workmanager().registerPeriodicTask(
            syncTaskKey,
            simpleTaskKey,
            frequency: const Duration(hours: 4),
            constraints: Constraints(
              networkType: NetworkType.connected,
              requiresBatteryNotLow: true,
            ),
            initialDelay: const Duration(minutes: 5),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
            tag: syncTaskKey,
          );
        }();
    _registerPeriodicSyncFuture = pendingRegister;

    try {
      await pendingRegister;
    } finally {
      if (identical(_registerPeriodicSyncFuture, pendingRegister)) {
        _registerPeriodicSyncFuture = null;
      }
    }
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
    PushNotificationService? pushNotifService;
    http.Client? httpClient;
    AppNetworkService? networkService;
    AppDatabase? db;
    NewsRepositoryImpl? newsRepo;

    try {
      if (kDebugMode) {
        debugPrint("🔄 [Background] Starting task: $task");
      }

      // Ensure SQLite library is correctly loaded in this isolate
      await setupSqliteLibrary();

      // 1. Initialize Flutter & Firebase
      WidgetsFlutterBinding.ensureInitialized();

      // Ensure dotenv is loaded in this isolate before Firebase options access.
      try {
        if (!dotenv.isInitialized) {
          await dotenv.load();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [Background] dotenv load failed: $e');
        }
      }
      var firebaseReady = Firebase.apps.isNotEmpty;
      if (Firebase.apps.isEmpty) {
        try {
          await DefaultFirebaseOptions.initializeApp();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [Background] Firebase init unavailable: $e');
          }
        }
      }
      firebaseReady = Firebase.apps.isNotEmpty;

      // 2. Instantiate Base Dependencies
      final prefs = await SharedPreferences.getInstance();
      final securePrefs = SecurePrefs(); // Wraps FlutterSecureStorage
      final dedupStore = NotificationDedupStore(prefs);
      final logger = StructuredLogger();
      final observability = ObservabilityService();

      SyncService? syncService;
      if (firebaseReady) {
        // 3. Instantiate PremiumRepositoryImpl with manual injection
        final premiumRepo = PremiumRepositoryImpl(
          securePrefs,
          prefs,
          FirebaseFirestore.instance,
          logger,
        );
        // Ensure local status is loaded
        await premiumRepo.refreshStatus();

        // 4. Instantiate SyncService
        syncService = SyncService(
          premiumRepo,
          observability,
          logger,
          prefs,
          FirebaseFirestore.instance,
          FirebaseAuth.instance,
        );
      } else if (kDebugMode) {
        debugPrint(
          ' [Background] Firebase unavailable, skipping Firestore/Auth sync work.',
        );
      }

      // 5. Instantiate PushNotificationService
      pushNotifService = PushNotificationService(logger, prefs, securePrefs);
      try {
        await pushNotifService.initialize(deferRemoteRegistration: true);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(' [Background] PushNotificationService init failed: $e');
        }
      }

      // 7. Instantiate NewsRepository
      await SSLPinning.initialize();
      httpClient = SSLPinning.createHttpClient();
      networkService = AppNetworkService();
      final rssService = RssService(httpClient, networkService, logger);
      db = AppDatabase();

      newsRepo = NewsRepositoryImpl(
        db,
        rssService,
        NewsFeedCategoryClassifier.instance,
        runBootstrap: false,
        scheduleLocalReclassificationBackfill: false,
        prefs: prefs,
      );

      // 8. Execute Task Logic
      switch (task) {
        case BackgroundService.simpleTaskKey:
        case BackgroundService.syncTaskKey:
          if (syncService != null) {
            if (kDebugMode) {
              debugPrint(" [Background] Flushing pending sync data...");
            }
            await syncService.flushPending();
          }

          if (kDebugMode) debugPrint(" [Background] Syncing news feed...");
          final langCode = prefs.getString('language_code') ?? 'en';
          final syncResult = await newsRepo.syncNews(
            locale: Locale(langCode),
            category: 'latest',
          );

          switch (syncResult) {
            case Left(value: final failure):
              logger.error('Background sync failed', failure);
            case Right(value: final newCount):
              if (newCount > 0 && pushNotifService.isEnabled) {
                final watermark =
                    dedupStore.lastNotifiedAt ??
                    DateTime.now().subtract(const Duration(hours: 6));

                // Query article IDs published after the watermark.
                final recentArticles =
                    await (db.select(db.articles)
                          ..where(
                            (t) => t.publishedAt.isBiggerThanValue(watermark),
                          )
                          ..orderBy([
                            (t) => OrderingTerm(
                              expression: t.publishedAt,
                              mode: OrderingMode.desc,
                            ),
                          ])
                          ..limit(50))
                        .get();

                final articleIds = recentArticles.map((a) => a.id).toList();

                // Filter out articles already shown in a previous notification.
                final unseenIds = dedupStore.filterUnseen(articleIds);

                if (unseenIds.isNotEmpty) {
                  // Cap the displayed count to avoid overwhelming the user.
                  final displayCount = unseenIds.length > 10
                      ? '10+'
                      : '${unseenIds.length}';

                  final title = langCode == 'bn'
                      ? 'নতুন খবর পাওয়া গেছে'
                      : 'Fresh News Available';
                  final body = langCode == 'bn'
                      ? '$displayCountটি নতুন সংবাদ আপনার জন্য অপেক্ষা করছে'
                      : '$displayCount new articles are ready for you';

                  // Use a stable notification ID so repeated syncs REPLACE the
                  // existing "new articles" notification instead of stacking.
                  const stableNotifId = 42;

                  await pushNotifService.showLocalNotification(
                    title: title,
                    body: body,
                    notificationId: stableNotifId,
                    payload: {'type': 'feed_update', 'count': unseenIds.length},
                  );

                  // Mark all notified articles as shown and update the watermark.
                  await dedupStore.markAllShown(unseenIds);
                  await dedupStore.updateLastNotifiedAt();
                  await dedupStore.cleanup();
                } else if (kDebugMode) {
                  debugPrint(
                    ' [Background] No unseen articles to notify about.',
                  );
                }
              }
          }

          if (kDebugMode) debugPrint(" [Background] Sync complete.");
          break;
      }

      return Future.value(true);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(" [Background] Task failed: $e");
        debugPrint(stack.toString());
      }
      return Future.value(false);
    } finally {
      newsRepo?.dispose();
      await pushNotifService?.dispose();
      httpClient?.close();
      networkService?.dispose();
      if (db != null) {
        await db.close();
      }
    }
  });
}
