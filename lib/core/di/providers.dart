import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:http/io_client.dart';
import '../../platform/identity/session_manager.dart' show IdentitySessionManager, IdentitySessionManagerImpl;
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
import '../../infrastructure/services/news_api_service.dart';
import '../../infrastructure/services/rss_service.dart';
import '../../infrastructure/services/payment_service.dart';
import '../../platform/persistence/app_database.dart';
import '../security/secure_prefs.dart';
import '../telemetry/structured_logger.dart';
import '../telemetry/observability_service.dart';
import '../utils/network_utils.dart';
import '../../infrastructure/network/app_network_service.dart';
import '../../infrastructure/services/remote_config_service.dart';
import '../../infrastructure/sync/sync_service.dart';
import '../../application/sync/sync_orchestrator.dart';
import '../../platform/identity/device_registry.dart';
import '../../platform/identity/device_registry_impl.dart';
import '../../platform/identity/trust_engine.dart';
import '../../application/identity/session_manager.dart' as am;
import '../../domain/facades/auth_facade.dart';
import '../../infrastructure/auth/auth_service_impl.dart';
import '../../infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import '../../platform/governance/governance_engine.dart';
import '../../infrastructure/services/hive_service.dart';
import '../../infrastructure/services/ml/ml_categorizer.dart';
import '../../infrastructure/sync/journal/sync_database.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../infrastructure/sync/sync_repository_impl.dart';
import '../../infrastructure/ai/features/feature_engineering_service.dart';
import '../../infrastructure/ai/collection/ai_event_collector.dart';
import '../../infrastructure/sync/integrity_service.dart';
import '../../infrastructure/persistence/vault/vault_database.dart';
import '../../presentation/features/tts/services/tts_database.dart';
import '../../presentation/features/tts/services/audio_cache_manager.dart';
import '../../presentation/features/tts/core/pipeline_orchestrator.dart';
import '../../infrastructure/persistence/saved_articles_service.dart';
import '../../infrastructure/external_apis/article_scraper_service.dart';
import '../../infrastructure/services/device_session_service.dart';
import '../../infrastructure/services/security_audit_service.dart';
import '../../infrastructure/services/app_verification_service.dart';
import '../../application/identity/device_trust_service.dart';
import '../../infrastructure/services/ml_service.dart';
import '../../infrastructure/services/ml/ml_sentiment_analyzer.dart';
import '../../infrastructure/ai/engine/quantized_tfidf_engine.dart';
import '../../application/ai/ranking/user_interest_service.dart';
// import '../../infrastructure/auth/auth_service_impl.dart'; // Duplicate
// import '../errors/error_handler.dart'; // Unused

import '../security/security_service.dart';
import '../network_quality_manager.dart';
import '../resilience/resilience_service.dart';
import '../enums/device_trust_state.dart';
import '../errors/security_exception.dart';
import '../security/device_trust_notifier.dart';
// import '../../application/identity/device_trust_service.dart'; // Duplicate

// —————————————————————————————————————————————————————————————————————————————
// 1. External/Third-Party Services
// —————————————————————————————————————————————————————————————————————————————

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  guardTrusted(ref);
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  guardTrusted(ref);
  return FirebaseFirestore.instance;
});
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
final messagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);
final analyticsProvider = Provider<FirebaseAnalytics>((ref) => FirebaseAnalytics.instance);
final crashlyticsProvider = Provider<FirebaseCrashlytics>((ref) => FirebaseCrashlytics.instance);
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());
final deviceInfoProvider = Provider<DeviceInfoPlugin>((ref) => DeviceInfoPlugin());
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());
final inAppPurchaseProvider = Provider<InAppPurchase>((ref) => InAppPurchase.instance);

final httpClientProvider = Provider<http.Client>((ref) {
  return IOClient(SSLPinning.getSecureHttpClient());
});

// —————————————————————————————————————————————————————————————————————————————
// 2. Core Infrastructure (Singletons)
// —————————————————————————————————————————————————————————————————————————————

final securePrefsProvider = Provider<SecurePrefs>((ref) => SecurePrefs());

final structuredLoggerProvider = Provider<StructuredLogger>((ref) => StructuredLogger());

final observabilityServiceProvider = Provider<ObservabilityService>((ref) => ObservabilityService());

final networkUtilsProvider = Provider<NetworkUtils>((ref) => NetworkUtils());

final appNetworkServiceProvider = Provider<AppNetworkService>((ref) => AppNetworkService());

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) => RemoteConfigService());

final mlServiceProvider = Provider<MLService>((ref) {
  return MLService(ref.watch(structuredLoggerProvider));
});

final securityAuditServiceProvider = Provider<SecurityAuditService>((ref) {
  return SecurityAuditService();
});

final appVerificationServiceProvider = Provider<AppVerificationService>((ref) {
  return AppVerificationService();
});

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) => VaultDatabase());
final ttsDatabaseProvider = Provider<TtsDatabase>((ref) => TtsDatabase(ref.watch(structuredLoggerProvider)));
final audioCacheProvider = Provider<AudioCacheManager>((ref) => AudioCacheManager());
final pipelineOrchestratorProvider = Provider<PipelineOrchestrator>((ref) {
  return PipelineOrchestrator(ref.watch(structuredLoggerProvider));
});

final articleScraperServiceProvider = Provider<ArticleScraperService>((ref) {
  return ArticleScraperService(
    ref.watch(httpClientProvider),
    ref.watch(structuredLoggerProvider),
  );
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
// 3. Application Services
// —————————————————————————————————————————————————————————————————————————————

final syncServiceProvider = Provider<SyncService>((ref) {
  final premiumRepo = ref.watch(premiumRepositoryProvider);
  final observability = ref.watch(observabilityServiceProvider);
  final logger = ref.watch(structuredLoggerProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return SyncService(premiumRepo, observability, logger, prefs, firestore, auth);
});

final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  final service = ref.watch(syncServiceProvider);
  final premium = ref.watch(premiumRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncOrchestrator(service, premium, prefs);
});

// —————————————————————————————————————————————————————————————————————————————
// 4. Repositories & Data Sources
// —————————————————————————————————————————————————————————————————————————————

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService(ref.watch(appNetworkServiceProvider));
});

final integrityServiceProvider = Provider<IntegrityService>((ref) {
  return IntegrityService(
    security: ref.watch(securityServiceProvider),
    logger: ref.watch(structuredLoggerProvider),
  );
});

final mlCategorizerProvider = Provider<MLCategorizer>((ref) {
  return MLCategorizer(ref.watch(mlServiceProvider));
});

final mlSentimentAnalyzerProvider = Provider<MLSentimentAnalyzer>((ref) {
  return MLSentimentAnalyzer(ref.watch(mlServiceProvider));
});

final newsApiServiceProvider = Provider<NewsApiService>((ref) {
  final client = ref.watch(httpClientProvider);
  final logger = ref.watch(structuredLoggerProvider);
  return NewsApiService(client, logger);
});

final rssServiceProvider = Provider<RssService>((ref) {
  final client = ref.watch(httpClientProvider);
  final networkService = ref.watch(appNetworkServiceProvider);
  final logger = ref.watch(structuredLoggerProvider);
  return RssService(client, networkService, logger);
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(appDatabaseProvider);
  final rss = ref.watch(rssServiceProvider);
  final api = ref.watch(newsApiServiceProvider);
  return NewsRepositoryImpl(prefs, db, rss, api);
});

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  final prefs = ref.watch(securePrefsProvider);
  final firestore = ref.watch(firestoreProvider);
  final remoteConfig = ref.watch(remoteConfigServiceProvider);
  final logger = ref.watch(structuredLoggerProvider);
  return PremiumRepositoryImpl(prefs, firestore, remoteConfig, logger);
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final iap = ref.watch(inAppPurchaseProvider);
  return PaymentService(iap);
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final payment = ref.watch(paymentServiceProvider);
  final auth = ref.watch(authFacadeProvider);
  return SubscriptionRepositoryImpl(prefs, payment, auth);
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

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final news = ref.watch(newsRepositoryProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  return SearchRepositoryImpl(news, settings);
});

// —————————————————————————————————————————————————————————————————————————————
// 5. AI & Ranking
// —————————————————————————————————————————————————————————————————————————————

final tfIdfEngineProvider = Provider<QuantizedTfIdfEngine>((ref) => QuantizedTfIdfEngine());

final userInterestServiceProvider = Provider<UserInterestService>((ref) {
  final engine = ref.watch(tfIdfEngineProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
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

final featureEngineeringServiceProvider = Provider<FeatureEngineeringService>((ref) {
  return FeatureEngineeringService(ref.watch(aiEventCollectorProvider));
});

// —————————————————————————————————————————————————————————————————————————————
// 5. Identity & Security
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
// 6. Authentication Facade
// —————————————————————————————————————————————————————————————————————————————

final authFacadeProvider = Provider<AuthFacade>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  final firestore = ref.read(firestoreProvider);
  final storage = ref.read(storageProvider);
  final session = ref.read(sessionManagerProvider);
  final premium = ref.read(premiumRepositoryProvider);
  final google = ref.read(googleSignInProvider);
  final logger = ref.read(structuredLoggerProvider);
  final securePrefs = ref.read(securePrefsProvider);
  
  return AuthService(
    auth: auth,
    firestore: firestore,
    storage: storage,
    sessionManager: session,
    premiumRepository: premium,
    googleSignIn: google,
    logger: logger,
    securePrefs: securePrefs,
  );
});

// —————————————————————————————————————————————————————————————————————————————
// 7. Security & Trust
// —————————————————————————————————————————————————————————————————————————————

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(ref.watch(structuredLoggerProvider));
});

final deviceTrustServiceProvider = Provider<DeviceTrustService>((ref) {
  return DeviceTrustService(security: ref.watch(securityServiceProvider));
});

final deviceTrustControllerProvider = StateNotifierProvider<DeviceTrustNotifier, DeviceTrustState>((ref) {
  return DeviceTrustNotifier(ref.watch(deviceTrustServiceProvider));
});

final deviceTrustStateProvider = Provider<DeviceTrustState>((ref) {
  return ref.watch(deviceTrustControllerProvider);
});

final networkQualityProvider = Provider<NetworkQualityManager>((ref) => NetworkQualityManager());

final resilienceServiceProvider = Provider<ResilienceService>((ref) {
  guardTrusted(ref);
  return ResilienceService();
});

final governanceEngineProvider = Provider<GovernanceEngine>((ref) {
  return GovernanceEngine(
    secureStorage: ref.watch(secureStorageProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

void guardTrusted(Ref ref) {
  final state = ref.read(deviceTrustStateProvider);
  debugPrint('🛡️ guardTrusted: Current State = $state');
  
  if (kDebugMode) {
    if (state != DeviceTrustState.trusted && state != DeviceTrustState.restricted) {
      throw SecurityException('Device is not in a trusted or restricted state (Current: $state). Access denied.');
    }
  } else {
    if (state != DeviceTrustState.trusted) {
      throw const SecurityException('Device is not trusted. Access denied.');
    }
  }
}
