import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../platform/identity/session_manager.dart'
    show IdentitySessionManager, IdentitySessionManagerImpl;
import '../security/ssl_pinning.dart';

// Repositories & Services
import '../../domain/repositories/premium_repository.dart';
import '../../infrastructure/repositories/premium_repository_impl.dart';
import '../../domain/repositories/news_repository.dart';
import '../../infrastructure/repositories/news_repository_impl.dart';
import '../../domain/interfaces/subscription_repository.dart';
import '../../infrastructure/repositories/subscription_repository_impl.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../infrastructure/repositories/favorites_repository_impl.dart';
import '../../domain/repositories/search_repository.dart';
import '../../infrastructure/repositories/search_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../infrastructure/repositories/settings_repository_impl.dart';
import '../../domain/repositories/source_repository.dart';
import '../../infrastructure/repositories/source_repository_impl.dart';
import '../../infrastructure/services/news/news_api_service.dart';
import '../../infrastructure/services/news/rss_service.dart';
import '../../infrastructure/services/payment/payment_service.dart';
import '../../infrastructure/services/notifications/push_notification_service.dart';
import '../../infrastructure/services/ml/news_feed_category_classifier.dart';
import '../../platform/persistence/app_database.dart';
import '../security/secure_prefs.dart';
import '../telemetry/structured_logger.dart';
import '../telemetry/observability_service.dart';
import '../utils/network_utils.dart';
import '../../infrastructure/network/app_network_service.dart';
import '../../infrastructure/services/config/remote_config_service.dart';
import '../../infrastructure/sync/services/sync_service.dart';
import '../../application/sync/sync_orchestrator.dart';
import '../../platform/identity/device_registry.dart';
import '../../platform/identity/device_registry_impl.dart';
import '../../platform/identity/trust_engine.dart';
import '../../domain/facades/auth_facade.dart';
import '../../infrastructure/auth/auth_service_impl.dart';
import '../../infrastructure/auth/google_sign_in_warmup_coordinator.dart';
import '../../infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import '../../platform/governance/governance_engine.dart';
import '../../infrastructure/services/storage/hive_service.dart';
import '../../infrastructure/services/ml/enhanced_ai_categorizer.dart';
import '../../infrastructure/services/ads/interstitial_ad_service.dart';
import '../../infrastructure/services/utils/rewarded_ad_service.dart';
import '../../infrastructure/sync/journal/sync_database.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../infrastructure/sync/sync_repository_impl.dart';
import '../../infrastructure/sync/services/integrity_service.dart';
import '../../infrastructure/ai/features/feature_engineering_service.dart';
import '../../infrastructure/ai/collection/ai_event_collector.dart';
import '../../infrastructure/persistence/vault/vault_database.dart';
import '../../presentation/features/tts/services/tts_database.dart';
import '../../presentation/features/tts/services/audio_cache_manager.dart';
import '../../presentation/features/tts/core/pipeline_orchestrator.dart';
import '../../infrastructure/persistence/services/saved_articles_service.dart';
import '../../infrastructure/external_apis/article_scraper_service.dart';
import '../../infrastructure/services/auth/device_session_service.dart';
import '../../infrastructure/services/auth/security_audit_service.dart';
import '../../infrastructure/services/auth/app_verification_service.dart';
import '../../application/identity/device_trust_service.dart';
import '../../infrastructure/services/ml/ml_service.dart';
import '../../infrastructure/services/ml/ml_sentiment_analyzer.dart';
import '../../infrastructure/ai/engine/quantized_tfidf_engine.dart';
import '../../application/ai/ranking/local_learning_engine.dart';
import '../../application/ai/ranking/user_interest_service.dart';
import '../bootstrap/startup_controller.dart';
import '../utils/source_logos.dart';

import '../security/security_service.dart';
import '../network/network_quality_manager.dart';
import '../resilience/resilience_service.dart';
import '../enums/device_trust_state.dart';
import '../errors/security_exception.dart';
import '../security/device_trust_notifier.dart';
import '../telemetry/debug_diagnostics_service.dart';

// —————————————————————————————————————————————————————————————————————————————
// 1. External/Third-Party Services
// —————————————————————————————————————————————————————————————————————————————

final sharedPreferencesProvider = StateProvider<SharedPreferences?>(
  (ref) => null,
);

final startupControllerProvider =
    StateNotifierProvider<StartupController, StartupSnapshot>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final securityService = ref.watch(securityServiceProvider);

      if (prefs == null) {
        return StartupController();
      }

      final runner = StartupBootstrapRunner(
        prefs: prefs,
        securityService: securityService,
      );
      return StartupController(runner: runner);
    });

final startupStateProvider = Provider<StartupSnapshot>((ref) {
  return ref.watch(startupControllerProvider);
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  guardTrusted(ref);
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  // Re-evaluate after startup transitions, but only fail if Firebase itself
  // is truly unavailable. This prevents false negatives when snapshot state
  // lags briefly behind Firebase app availability during hot restart/boot.
  ref.watch(startupStateProvider);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase app not initialized yet.');
  }
  return FirebaseFirestore.instance;
});

final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);
final messagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);
final analyticsProvider = Provider<FirebaseAnalytics>(
  (ref) => FirebaseAnalytics.instance,
);
final crashlyticsProvider = Provider<FirebaseCrashlytics>(
  (ref) => FirebaseCrashlytics.instance,
);

String? _normalizedGoogleClientId(String? rawValue) {
  final value = rawValue?.trim();
  if (value == null || value.isEmpty) return null;

  final upper = value.toUpperCase();
  if (upper.contains('YOUR_GOOGLE_CLIENT_ID_HERE') ||
      upper.contains('YOUR_FIREBASE_ANDROID_CLIENT_ID_HERE') ||
      !value.endsWith('.apps.googleusercontent.com')) {
    return null;
  }

  return value;
}

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  final googleClientId = _normalizedGoogleClientId(
    dotenv.isInitialized ? dotenv.env['GOOGLE_CLIENT_ID'] : null,
  );

  // For iOS and Web, clientId is required.
  // For Android, clientId is picked from google-services.json,
  // and if serverClientId is omitted the native configuration can still
  // fall back to the value generated from google-services.json.
  return GoogleSignIn(
    clientId: (defaultTargetPlatform == TargetPlatform.iOS || kIsWeb)
        ? googleClientId
        : null,
    serverClientId: googleClientId,
    scopes: ['email'],
  );
});
final googleSignInWarmupProvider = Provider<GoogleSignInWarmupCoordinator>((
  ref,
) {
  return GoogleSignInWarmupCoordinator(ref.watch(googleSignInProvider));
});
final deviceInfoProvider = Provider<DeviceInfoPlugin>(
  (ref) => DeviceInfoPlugin(),
);
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => SecurePrefs.sharedStorage,
);
final inAppPurchaseProvider = Provider<InAppPurchase>(
  (ref) => InAppPurchase.instance,
);

final httpClientProvider = Provider<http.Client>((ref) {
  return SSLPinning.createHttpClient();
});

// —————————————————————————————————————————————————————————————————————————————
// 2. Core Infrastructure (Singletons)
// —————————————————————————————————————————————————————————————————————————————

final securePrefsProvider = Provider<SecurePrefs>((ref) => SecurePrefs());

final structuredLoggerProvider = Provider<StructuredLogger>(
  (ref) => StructuredLogger(),
);

final observabilityServiceProvider = Provider<ObservabilityService>(
  (ref) => ObservabilityService(),
);

final debugDiagnosticsServiceProvider = Provider<DebugDiagnosticsService>(
  (ref) => DebugDiagnosticsService(),
);

final networkUtilsProvider = Provider<NetworkUtils>((ref) => NetworkUtils());

final appNetworkServiceProvider = ChangeNotifierProvider<AppNetworkService>(
  (ref) => AppNetworkService(),
);

final hiveServiceProvider = Provider<HiveService>((ref) {
  // Keep HiveService stable; network changes should not recreate cache service.
  return HiveService(ref.read(appNetworkServiceProvider));
});

final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => RemoteConfigService(),
);

final mlServiceProvider = Provider<MLService>((ref) {
  return MLService(ref.watch(structuredLoggerProvider));
});

final securityAuditServiceProvider = Provider<SecurityAuditService>((ref) {
  return SecurityAuditService();
});

final appVerificationServiceProvider = Provider<AppVerificationService>((ref) {
  return AppVerificationService();
});

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) {
  final db = VaultDatabase();
  ref.onDispose(() {
    VaultDatabase.closeDatabase();
  });
  return db;
});

final ttsDatabaseProvider = Provider<TtsDatabase>((ref) {
  final db = TtsDatabase(ref.watch(structuredLoggerProvider));
  ref.onDispose(() {
    db.close();
  });
  return db;
});

final audioCacheProvider = Provider<AudioCacheManager>(
  (ref) => AudioCacheManager(),
);

final pipelineOrchestratorProvider = Provider<PipelineOrchestrator>((ref) {
  return PipelineOrchestrator(ref.watch(structuredLoggerProvider));
});

final articleScraperServiceProvider = Provider<ArticleScraperService>((ref) {
  return ArticleScraperService(
    ref.watch(httpClientProvider),
    ref.watch(structuredLoggerProvider),
  );
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = PushNotificationService(
    ref.watch(structuredLoggerProvider),
    prefs,
    ref.watch(securePrefsProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final savedArticlesServiceProvider = Provider<SavedArticlesService>((ref) {
  return SavedArticlesService(
    ref.watch(articleScraperServiceProvider),
    ref.watch(structuredLoggerProvider),
  );
});

final deviceSessionServiceProvider = Provider<DeviceSessionService>((ref) {
  return DeviceSessionService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    auditService: ref.watch(securityAuditServiceProvider),
    appVerification: ref.watch(appVerificationServiceProvider),
    securePrefs: ref.watch(securePrefsProvider),
  );
});

// —————————————————————————————————————————————————————————————————————————————
// 3. ML & AI Services
// —————————————————————————————————————————————————————————————————————————————

/// ✨ Enhanced AI Categorizer Provider
///
/// Provides the singleton instance of EnhancedAICategorizer for accurate
/// categorization of news articles into: national, international, sports, entertainment
///
/// Features:
/// - Multi-stage categorization (Memory Cache → Disk Cache → AI → Keyword Fallback)
/// - Language detection (English & Bengali)
/// - High-confidence pattern matching with regex
/// - Comprehensive keyword databases (500+ keywords per category)
/// - Automatic disambiguation (e.g., Shakib cricketer vs Shakib Khan actor)
/// - Concurrent request limiting (max 10 parallel API calls)
///
/// Usage:
/// ```dart
/// final categorizer = ref.watch(enhancedAICategorizerProvider);
/// final category = await categorizer.categorizeArticle(
///   title: "Bangladesh vs India Cricket Match",
///   description: "Exciting ODI match scheduled...",
/// );
/// // Returns: 'sports'
/// ```
final enhancedAICategorizerProvider = Provider<EnhancedAICategorizer>((ref) {
  debugPrint('🤖 Initializing EnhancedAICategorizer...');
  return EnhancedAICategorizer.instance;
});

final mlSentimentAnalyzerProvider = Provider<MLSentimentAnalyzer>((ref) {
  return MLSentimentAnalyzer(ref.watch(mlServiceProvider));
});

// —————————————————————————————————————————————————————————————————————————————
// 4. API & Service Integrations
// —————————————————————————————————————————————————————————————————————————————

final newsApiServiceProvider = Provider<NewsApiService>((ref) {
  final logger = ref.watch(structuredLoggerProvider);
  final apiService = NewsApiService(logger);
  return apiService;
});

final rssServiceProvider = Provider<RssService>((ref) {
  // Keep RssService stable. AppNetworkService is a ChangeNotifier whose
  // internal state changes frequently; we need the same instance, not provider
  // re-creation on each notifyListeners().
  final client = ref.read(httpClientProvider);
  final networkService = ref.read(appNetworkServiceProvider);
  final logger = ref.read(structuredLoggerProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final rssService = RssService(client, networkService, logger, prefs: prefs);
  return rssService;
});

// —————————————————————————————————————————————————————————————————————————————
// 5. Repository Providers
// —————————————————————————————————————————————————————————————————————————————

final newsFeedCategoryClassifierProvider = Provider<NewsFeedCategoryClassifier>(
  (ref) {
    return NewsFeedCategoryClassifier.instance;
  },
);

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final rssService = ref.watch(rssServiceProvider);
  final classifier = ref.watch(newsFeedCategoryClassifierProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  final repository = NewsRepositoryImpl(
    db,
    rssService,
    classifier,
    runBootstrap: false,
    prefs: prefs,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  final startup = ref.watch(startupStateProvider);
  final prefs = ref.watch(sharedPreferencesProvider); // Used for sync check
  final securePrefs = ref.watch(securePrefsProvider);
  final logger = ref.watch(structuredLoggerProvider);

  if (!startup.firebaseReady || Firebase.apps.isEmpty) {
    return StubPremiumRepository(prefs);
  }

  final firestore = ref.watch(firestoreProvider);
  return PremiumRepositoryImpl(securePrefs, prefs, firestore, logger);
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final iap = ref.watch(inAppPurchaseProvider);
  return PaymentService(iap);
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final payment = ref.watch(paymentServiceProvider);
  final auth = ref.watch(authFacadeProvider);
  final premium = ref.watch(premiumRepositoryProvider);
  return SubscriptionRepositoryImpl(prefs, payment, auth, premium);
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final sync = ref.watch(syncServiceProvider);
  final db = ref.watch(appDatabaseProvider);
  return FavoritesRepositoryImpl(prefs, sync, db);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(prefs);
});

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SourceRepositoryImpl(prefs);
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final news = ref.watch(newsRepositoryProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  return SearchRepositoryImpl(news, settings);
});

// —————————————————————————————————————————————————————————————————————————————
// 6. Sync Services
// —————————————————————————————————————————————————————————————————————————————

final syncServiceProvider = Provider<SyncService>((ref) {
  final syncGateReady = ref.watch(
    startupStateProvider.select((s) => s.isReady && s.firebaseReady),
  );

  final observability = ref.watch(observabilityServiceProvider);
  final logger = ref.watch(structuredLoggerProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  if (!syncGateReady || Firebase.apps.isEmpty) {
    return SyncService.disabled(observability, logger, prefs);
  }
  final premiumRepo = ref.watch(premiumRepositoryProvider);
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return SyncService(
    premiumRepo,
    observability,
    logger,
    prefs,
    firestore,
    auth,
  );
});

final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final orchestrator = SyncOrchestrator.disabled(prefs);

  void syncAttachment({bool? gateReadyOverride}) {
    final bool syncGateReady =
        gateReadyOverride == true ||
        (gateReadyOverride == null &&
            ref.read(
              startupStateProvider.select((s) => s.isReady && s.firebaseReady),
            ));
    if (!syncGateReady || Firebase.apps.isEmpty) {
      orchestrator.attachSyncService(null);
      return;
    }
    orchestrator.attachSyncService(ref.read(syncServiceProvider));
  }

  syncAttachment();

  ref.listen<bool>(
    startupStateProvider.select((s) => s.isReady && s.firebaseReady),
    (previous, next) {
      syncAttachment(gateReadyOverride: next);
    },
  );

  ref.listen<SyncService>(syncServiceProvider, (previous, next) {
    syncAttachment();
  });

  return orchestrator;
});

// —————————————————————————————————————————————————————————————————————————————
// 7. AI & Ranking
// —————————————————————————————————————————————————————————————————————————————

final tfIdfEngineProvider = Provider<QuantizedTfIdfEngine>(
  (ref) => QuantizedTfIdfEngine(),
);

final userInterestServiceProvider = Provider<UserInterestService>((ref) {
  final engine = ref.watch(tfIdfEngineProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  if (prefs == null) {
    return UserInterestService.disabled(engine);
  }
  return UserInterestService(engine, prefs);
});

final rankingPipelineProvider = Provider<RankingPipeline>((ref) {
  final repo = ref.watch(newsRepositoryProvider);
  final interest = ref.watch(userInterestServiceProvider);
  return RankingPipeline(repo, interest);
});

final syncDatabaseProvider = Provider<SyncDatabase>((ref) {
  return SyncDatabase();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepositoryImpl(ref.watch(syncDatabaseProvider));
});

final aiEventCollectorProvider = Provider<AIEventCollector>((ref) {
  return AIEventCollector(ref.watch(syncRepositoryProvider));
});

final localLearningEngineProvider = Provider<LocalLearningEngine>((ref) {
  final engine = LocalLearningEngine(
    ref.watch(userInterestServiceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    eventCollector: ref.watch(aiEventCollectorProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final featureEngineeringServiceProvider = Provider<FeatureEngineeringService>((
  ref,
) {
  return FeatureEngineeringService(ref.watch(aiEventCollectorProvider));
});

// —————————————————————————————————————————————————————————————————————————————
// 8. Identity & Security
// —————————————————————————————————————————————————————————————————————————————

final deviceRegistryProvider = Provider<DeviceRegistry>((ref) {
  final deviceInfo = ref.watch(deviceInfoProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return DeviceRegistryImpl(deviceInfo, secureStorage);
});

final trustEngineProvider = Provider<TrustEngine>((ref) {
  final registry = ref.watch(deviceRegistryProvider);
  return TrustEngineImpl(registry);
});

final sessionManagerProvider = Provider<IdentitySessionManager>((ref) {
  final registry = ref.watch(deviceRegistryProvider);
  final trust = ref.watch(trustEngineProvider);
  return IdentitySessionManagerImpl(registry, trust);
});

// —————————————————————————————————————————————————————————————————————————————
// 9. Authentication Facade
// —————————————————————————————————————————————————————————————————————————————

final authFacadeProvider = Provider<AuthFacade>((ref) {
  return AuthService(ref);
});

// —————————————————————————————————————————————————————————————————————————————
// 10. Security & Trust
// —————————————————————————————————————————————————————————————————————————————

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final integrityServiceProvider = Provider<IntegrityService>((ref) {
  return IntegrityService(
    security: ref.watch(securityServiceProvider),
    logger: ref.watch(structuredLoggerProvider),
  );
});

final deviceTrustServiceProvider = Provider<DeviceTrustService>((ref) {
  return DeviceTrustService(
    security: ref.watch(securityServiceProvider),
    logger: ref.watch(structuredLoggerProvider),
  );
});

final deviceTrustControllerProvider =
    StateNotifierProvider<DeviceTrustNotifier, DeviceTrustState>((ref) {
      return DeviceTrustNotifier(ref.watch(deviceTrustServiceProvider));
    });

final deviceTrustStateProvider = Provider<DeviceTrustState>((ref) {
  return ref.watch(deviceTrustControllerProvider);
});

final networkQualityProvider = Provider<NetworkQualityManager>(
  (ref) => NetworkQualityManager(),
);

final resilienceServiceProvider = Provider<ResilienceService>((ref) {
  guardTrusted(ref);
  return ResilienceService();
});

final governanceEngineProvider = Provider<GovernanceEngine>((ref) {
  final startup = ref.watch(startupStateProvider);
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  const secureStorage = SecurePrefs.sharedStorage;

  if (!startup.firebaseReady || Firebase.apps.isEmpty || prefs == null) {
    return GovernanceEngine.disabled(secureStorage);
  }

  return GovernanceEngine(secureStorage: secureStorage, prefs: prefs, db: db);
});

// —————————————————————————————————————————————————————————————————————————————
// 11. Database Providers
// —————————————————————————————————————————————————————————————————————————————

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// —————————————————————————————————————————————————————————————————————————————
// 12. Ad Services
// —————————————————————————————————————————————————————————————————————————————

final interstitialAdServiceProvider = Provider<InterstitialAdService>((ref) {
  final repo = ref.watch(premiumRepositoryProvider);
  final networkService = ref.read(appNetworkServiceProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final service = InterstitialAdService(
    repo,
    networkService: networkService,
    prefs: prefs,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  final repo = ref.watch(premiumRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final networkService = ref.read(appNetworkServiceProvider);
  final service = RewardedAdService(repo, prefs, networkService);
  ref.onDispose(() => service.dispose());
  return service;
});

// —————————————————————————————————————————————————————————————————————————————
// 13. Helper Functions
// —————————————————————————————————————————————————————————————————————————————

/// Guard function to ensure device is trusted before accessing sensitive services
void guardTrusted(Ref ref) {
  final state = ref.read(deviceTrustControllerProvider);

  // ✅ FIXED: Allow unknown/verifying to avoid startup race conditions.
  // Only throw if explicitly blocked or restricted.
  if (state == DeviceTrustState.blocked ||
      state == DeviceTrustState.restricted) {
    throw SecurityException(
      'Device security check failed. Access denied. (state: $state)',
    );
  }
}

/// Utility function to safely dispose of providers
/// Use in cleanup scenarios or when reinitializing providers
void disposeProviders(Ref ref) {
  try {
    // Dispose AI Categorizer
    ref.read(enhancedAICategorizerProvider).dispose();
    debugPrint('✅ EnhancedAICategorizer disposed');

    // Dispose HTTP Client
    ref.read(httpClientProvider).close();
    debugPrint('✅ HTTP Client disposed');

    debugPrint('✅ All providers disposed successfully');
  } catch (e) {
    debugPrint('⚠️ Error disposing providers: $e');
  }
}
final publisherLogoMapProvider = Provider<Map<String, String>>((ref) {
  return SourceLogos.logos;
});
