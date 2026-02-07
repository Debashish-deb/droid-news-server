// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:device_info_plus/device_info_plus.dart' as _i833;
import 'package:firebase_analytics/firebase_analytics.dart' as _i398;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_crashlytics/firebase_crashlytics.dart' as _i141;
import 'package:firebase_messaging/firebase_messaging.dart' as _i892;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:http/http.dart' as _i519;
import 'package:in_app_purchase/in_app_purchase.dart' as _i690;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../../application/ai/ranking/user_interest_service.dart' as _i341;
import '../../core/premium_service.dart' as _i653;
import '../../core/security/secure_prefs.dart' as _i647;
import '../../core/telemetry/observability_service.dart' as _i671;
import '../../core/telemetry/structured_logger.dart' as _i672;
import '../../core/utils/network_utils.dart' as _i698;
import '../../domain/facades/auth_facade.dart' as _i716;
import '../../domain/interfaces/subscription_repository.dart' as _i459;
import '../../domain/repositories/favorites_repository.dart' as _i550;
import '../../domain/repositories/news_repository.dart' as _i88;
import '../../domain/repositories/search_repository.dart' as _i475;
import '../../domain/repositories/settings_repository.dart' as _i415;
import '../../infrastructure/ai/engine/quantized_tfidf_engine.dart' as _i206;
import '../../infrastructure/ai/ranking/pipeline/ranking_pipeline.dart'
    as _i434;
import '../../infrastructure/auth/auth_service_impl.dart' as _i1033;
import '../../infrastructure/external_apis/article_scraper_service.dart'
    as _i545;
import '../../infrastructure/network/app_network_service.dart' as _i200;
import '../../infrastructure/network/intercepted_dio_client.dart' as _i217;
import '../../infrastructure/persistence/saved_articles_service.dart' as _i393;
import '../../infrastructure/persistence/vault/vault_database.dart' as _i519;
import '../../infrastructure/repositories/favorites_repository_impl.dart'
    as _i357;
import '../../infrastructure/repositories/news_repository_impl.dart' as _i830;
import '../../infrastructure/repositories/search_repository_impl.dart' as _i548;
import '../../infrastructure/repositories/settings_repository_impl.dart'
    as _i468;
import '../../infrastructure/repositories/subscription_repository_impl.dart'
    as _i413;
import '../../infrastructure/services/feature_flag_service.dart' as _i822;
import '../../infrastructure/services/payment_service.dart' as _i741;
import '../../infrastructure/services/push_notification_service.dart' as _i483;
import '../../infrastructure/services/receipt_verification_service.dart'
    as _i240;
import '../../infrastructure/services/remote_config_service.dart' as _i265;
import '../../infrastructure/services/rss_service.dart' as _i899;
import '../../infrastructure/sync/sync_service.dart' as _i1001;
import '../../platform/identity/device_registry.dart' as _i825;
import '../../platform/identity/device_registry_impl.dart' as _i710;
import '../../platform/identity/session_manager.dart' as _i297;
import '../../platform/identity/trust_engine.dart' as _i1;
import '../../platform/persistence/app_database.dart' as _i99;
import '../../platform/sync_engine/event_journal_service.dart' as _i642;
import '../../presentation/features/tts/core/pipeline_orchestrator.dart'
    as _i484;
import '../../presentation/features/tts/services/audio_cache_manager.dart'
    as _i9;
import '../../presentation/features/tts/services/tts_database.dart' as _i694;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => registerModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i647.SecurePrefs>(() => _i647.SecurePrefs());
    gh.lazySingleton<_i698.NetworkUtils>(() => _i698.NetworkUtils());
    gh.lazySingleton<_i672.StructuredLogger>(() => _i672.StructuredLogger());
    gh.lazySingleton<_i59.FirebaseAuth>(() => registerModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(() => registerModule.firestore);
    gh.lazySingleton<_i457.FirebaseStorage>(() => registerModule.storage);
    gh.lazySingleton<_i892.FirebaseMessaging>(() => registerModule.messaging);
    gh.lazySingleton<_i398.FirebaseAnalytics>(() => registerModule.analytics);
    gh.lazySingleton<_i141.FirebaseCrashlytics>(
        () => registerModule.crashlytics);
    gh.lazySingleton<_i116.GoogleSignIn>(() => registerModule.googleSignIn);
    gh.lazySingleton<_i833.DeviceInfoPlugin>(() => registerModule.deviceInfo);
    gh.lazySingleton<_i558.FlutterSecureStorage>(
        () => registerModule.secureStorage);
    gh.lazySingleton<_i690.InAppPurchase>(() => registerModule.inAppPurchase);
    gh.lazySingleton<_i519.Client>(() => registerModule.httpClient);
    gh.lazySingleton<_i99.AppDatabase>(() => _i99.AppDatabase());
    gh.lazySingleton<_i200.AppNetworkService>(() => _i200.AppNetworkService());
    gh.lazySingleton<_i217.InterceptedDioClient>(
        () => _i217.InterceptedDioClient());
    gh.lazySingleton<_i206.QuantizedTfIdfEngine>(
        () => _i206.QuantizedTfIdfEngine());
    gh.lazySingleton<_i519.VaultDatabase>(() => _i519.VaultDatabase());
    gh.lazySingleton<_i240.ReceiptVerificationService>(
        () => _i240.ReceiptVerificationService());
    gh.lazySingleton<_i265.RemoteConfigService>(
        () => _i265.RemoteConfigService());
    gh.lazySingleton<_i9.AudioCacheManager>(() => _i9.AudioCacheManager());
    gh.lazySingleton<_i694.TtsDatabase>(() => _i694.TtsDatabase());
    gh.lazySingleton<_i825.DeviceRegistry>(() => _i710.DeviceRegistryImpl(
          gh<_i833.DeviceInfoPlugin>(),
          gh<_i558.FlutterSecureStorage>(),
        ));
    gh.lazySingleton<_i1.TrustEngine>(
        () => _i1.TrustEngineImpl(gh<_i825.DeviceRegistry>()));
    gh.lazySingleton<_i415.SettingsRepository>(
        () => _i468.SettingsRepositoryImpl(gh<_i460.SharedPreferences>()));
    gh.lazySingleton<_i341.UserInterestService>(() => _i341.UserInterestService(
          gh<_i206.QuantizedTfIdfEngine>(),
          gh<_i460.SharedPreferences>(),
        ));
    gh.lazySingleton<_i545.ArticleScraperService>(
        () => _i545.ArticleScraperService(
              gh<_i519.Client>(),
              gh<_i672.StructuredLogger>(),
            ));
    gh.lazySingleton<_i741.PaymentService>(
        () => _i741.PaymentService(gh<_i690.InAppPurchase>()));
    gh.lazySingleton<_i642.EventJournalService>(
        () => _i642.EventJournalService(gh<_i99.AppDatabase>()));
    gh.lazySingleton<_i297.IdentitySessionManager>(
        () => _i297.IdentitySessionManagerImpl(
              gh<_i825.DeviceRegistry>(),
              gh<_i1.TrustEngine>(),
            ));
    gh.lazySingleton<_i653.PremiumService>(() => _i653.PremiumService(
          prefs: gh<_i460.SharedPreferences>(),
          injectedSecurePrefs: gh<_i647.SecurePrefs>(),
          injectedRemoteConfig: gh<_i265.RemoteConfigService>(),
        ));
    gh.lazySingleton<_i484.PipelineOrchestrator>(
        () => _i484.PipelineOrchestrator(gh<_i672.StructuredLogger>()));
    gh.lazySingleton<_i483.PushNotificationService>(
        () => _i483.PushNotificationService(
              gh<_i672.StructuredLogger>(),
              gh<_i460.SharedPreferences>(),
            ));
    gh.lazySingleton<_i822.FeatureFlagService>(
        () => _i822.FeatureFlagService(gh<_i265.RemoteConfigService>()));
    gh.lazySingleton<_i899.RssService>(() => _i899.RssService(
          gh<_i519.Client>(),
          gh<_i200.AppNetworkService>(),
          gh<_i672.StructuredLogger>(),
        ));
    gh.lazySingleton<_i1001.SyncService>(() => _i1001.SyncService(
          gh<_i653.PremiumService>(),
          gh<_i671.ObservabilityService>(),
          gh<_i672.StructuredLogger>(),
        ));
    gh.lazySingleton<_i393.SavedArticlesService>(
        () => _i393.SavedArticlesService(
              gh<_i545.ArticleScraperService>(),
              gh<_i672.StructuredLogger>(),
            ));
    gh.lazySingleton<_i88.NewsRepository>(() => _i830.NewsRepositoryImpl(
          gh<_i460.SharedPreferences>(),
          gh<_i99.AppDatabase>(),
          gh<_i899.RssService>(),
        ));
    gh.lazySingleton<_i550.FavoritesRepository>(
        () => _i357.FavoritesRepositoryImpl(
              gh<_i460.SharedPreferences>(),
              gh<_i1001.SyncService>(),
              gh<_i99.AppDatabase>(),
            ));
    gh.lazySingleton<_i434.RankingPipeline>(() => _i434.RankingPipeline(
          gh<_i88.NewsRepository>(),
          gh<_i341.UserInterestService>(),
        ));
    gh.lazySingleton<_i716.AuthFacade>(() => _i1033.AuthService(
          gh<_i59.FirebaseAuth>(),
          gh<_i974.FirebaseFirestore>(),
          gh<_i457.FirebaseStorage>(),
          gh<_i297.IdentitySessionManager>(),
          gh<_i653.PremiumService>(),
          gh<_i116.GoogleSignIn>(),
          gh<_i672.StructuredLogger>(),
        ));
    gh.lazySingleton<_i475.SearchRepository>(() => _i548.SearchRepositoryImpl(
          gh<_i88.NewsRepository>(),
          gh<_i415.SettingsRepository>(),
        ));
    gh.lazySingleton<_i459.SubscriptionRepository>(
        () => _i413.SubscriptionRepositoryImpl(
              gh<_i460.SharedPreferences>(),
              gh<_i741.PaymentService>(),
              gh<_i716.AuthFacade>(),
            ));
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
