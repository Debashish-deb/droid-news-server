import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart' as di;
import '../../domain/facades/auth_facade.dart';
import '../../application/identity/session_manager.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../infrastructure/services/feature_flag_service.dart';
import '../../infrastructure/persistence/vault/vault_database.dart';
import '../../infrastructure/services/assets_data_loader.dart';
import '../../application/ai/ranking/user_interest_service.dart' show UserInterestService;
import '../../infrastructure/services/remote_config_service.dart';
import '../features/tts/services/tts_manager.dart';
import '../features/tts/services/tts_database.dart';
import '../features/tts/services/audio_cache_manager.dart';
import '../features/tts/core/tts_analytics.dart';
import '../features/tts/core/synthesis_circuit_breaker.dart';
import '../features/tts/core/tts_performance_monitor.dart';
import '../features/tts/domain/repositories/tts_repository.dart';
import '../features/tts/data/repositories/tts_repository_impl.dart';
import '../../domain/interfaces/subscription_repository.dart';
import '../../infrastructure/persistence/saved_articles_service.dart';

// —————————————————————————————————————————————————————————————————————————————
// 3. Identity & Access
// —————————————————————————————————————————————————————————————————————————————

final authServiceProvider = Provider<AuthFacade>((ref) {
  return ref.watch(di.authFacadeProvider);
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(
    auth: ref.watch(authServiceProvider),
    trust: ref.watch(di.deviceTrustServiceProvider),
    remoteConfig: ref.watch(di.remoteConfigServiceProvider),
  );
});

final premiumServiceProvider = Provider<PremiumRepository>((ref) {
  return ref.watch(di.premiumRepositoryProvider);
});

// —————————————————————————————————————————————————————————————————————————————
// 4. Feature: TTS
// —————————————————————————————————————————————————————————————————————————————

final ttsDatabaseProvider = Provider<TtsDatabase>((ref) {
  return ref.watch(di.ttsDatabaseProvider);
});
final audioCacheProvider = Provider<AudioCacheManager>((ref) {
  return ref.watch(di.audioCacheProvider);
});
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
    pipelineOrchestrator: ref.watch(di.pipelineOrchestratorProvider),
    cacheManager: ref.watch(audioCacheProvider),
  );
});

// —————————————————————————————————————————————————————————————————————————————
// 5. Repositories (News, Settings, Favorites)
// —————————————————————————————————————————————————————————————————————————————

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) => ref.watch(di.vaultDatabaseProvider));

// —————————————————————————————————————————————————————————————————————————————
// 6. Misc Services
// —————————————————————————————————————————————————————————————————————————————

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
   final rc = ref.watch(di.remoteConfigServiceProvider);
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

final userInterestProvider = Provider<UserInterestService>((ref) {
  return ref.watch(di.userInterestServiceProvider);
});

final subscriptionRepoProvider = Provider<SubscriptionRepository>((ref) {
  return ref.watch(di.subscriptionRepositoryProvider);
});
