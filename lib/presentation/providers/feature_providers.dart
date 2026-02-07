import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bootstrap/di/injection_container.dart' show sl;
import '../../domain/facades/auth_facade.dart';

// Dependencies
import '../../infrastructure/persistence/saved_articles_service.dart';
import '../../core/providers.dart';
import '../../core/premium_service.dart';
import '../../domain/interfaces/subscription_repository.dart';
import '../../application/identity/session_manager.dart';
import '../../infrastructure/services/feature_flag_service.dart';
import '../../infrastructure/persistence/vault/vault_database.dart';
import '../../infrastructure/services/assets_data_loader.dart';

// Repositories

// Features
import '../features/tts/services/tts_manager.dart';
import '../features/tts/services/tts_database.dart';
import '../features/tts/services/audio_cache_manager.dart';
import '../features/tts/core/tts_analytics.dart';
import '../features/tts/core/synthesis_circuit_breaker.dart';
import '../features/tts/core/tts_performance_monitor.dart';
import '../features/tts/domain/repositories/tts_repository.dart';
import '../features/tts/core/pipeline_orchestrator.dart';
import '../features/tts/data/repositories/tts_repository_impl.dart';

import '../../application/ai/ranking/user_interest_service.dart' show UserInterestService;

// —————————————————————————————————————————————————————————————————————————————
// 3. Identity & Access
// —————————————————————————————————————————————————————————————————————————————

final authServiceProvider = Provider<AuthFacade>((ref) {
  // Use DI to get AuthFacade instance
  return sl<AuthFacade>();
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  // Wait for RemoteConfig
  final remoteConfigAsync = ref.watch(remoteConfigProvider);
  // If remote config isn't ready, we might issue a basic version or throw.
  // For simplicity handling here:
  return SessionManager(
    auth: ref.watch(authServiceProvider),
    trust: ref.watch(deviceTrustServiceProvider),
    remoteConfig: remoteConfigAsync.asData?.value ?? ref.watch(featureFlagServiceProvider).remoteConfig, // fallback
  );
});

final premiumServiceProvider = Provider<PremiumService>((ref) {
  return sl<PremiumService>();
});


// —————————————————————————————————————————————————————————————————————————————
// 4. Feature: TTS
// —————————————————————————————————————————————————————————————————————————————

final ttsDatabaseProvider = Provider<TtsDatabase>((ref) => sl<TtsDatabase>());
final audioCacheProvider = Provider<AudioCacheManager>((ref) => sl<AudioCacheManager>());
final ttsAnalyticsProvider = Provider<TtsAnalytics>((ref) => TtsAnalytics());

final ttsPerformanceMonitorProvider = Provider<TtsPerformanceMonitor>((ref) {
  return TtsPerformanceMonitor(analytics: ref.watch(ttsAnalyticsProvider));
});

final synthesisCircuitBreakerProvider = Provider<SynthesisCircuitBreaker>((ref) {
  return SynthesisCircuitBreaker(analytics: ref.watch(ttsAnalyticsProvider));
});

final ttsRepositoryProvider = Provider<TtsRepository>((ref) {
  return TtsRepositoryImpl(
    db: ref.watch(ttsDatabaseProvider),
    cacheManager: ref.watch(audioCacheProvider),
  );
});

final ttsManagerProvider = Provider<TtsManager>((ref) {
  return TtsManager(
    repository: ref.watch(ttsRepositoryProvider),
    analytics: ref.watch(ttsAnalyticsProvider),
    circuitBreaker: ref.watch(synthesisCircuitBreakerProvider),
    performanceMonitor: ref.watch(ttsPerformanceMonitorProvider),
    pipelineOrchestrator: sl<PipelineOrchestrator>(),
    cacheManager: ref.watch(audioCacheProvider),
  );
});

// —————————————————————————————————————————————————————————————————————————————
// 5. Repositories (News, Settings, Favorites)
// —————————————————————————————————————————————————————————————————————————————

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) => sl<VaultDatabase>());

// Repositories are now provided in app_settings_providers.dart for better consistency

// —————————————————————————————————————————————————————————————————————————————
// 6. Misc Services
// —————————————————————————————————————————————————————————————————————————————

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
   // Needs RemoteConfig
   final rc = ref.watch(remoteConfigProvider).asData?.value;
    if (rc == null) throw Exception("Remote Config not ready");
   return FeatureFlagService(rc); 
});

final assetsLoaderProvider = Provider<AssetsDataLoader>((ref) => AssetsDataLoader());

final newspaperDataProvider = FutureProvider<List<dynamic>>((ref) async {
  final loader = ref.watch(assetsLoaderProvider);
  await loader.loadData();
  return loader.getNewspapers();
});

final magazineDataProvider = FutureProvider<List<dynamic>>((ref) async {
  final loader = ref.watch(assetsLoaderProvider);
  await loader.loadData();
  return loader.getMagazines();
});

final savedArticlesServiceProvider = Provider<SavedArticlesService>((ref) {
  return sl<SavedArticlesService>();
});

final userInterestProvider = Provider<UserInterestService>((ref) => sl<UserInterestService>());

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return sl<SubscriptionRepository>();
});
