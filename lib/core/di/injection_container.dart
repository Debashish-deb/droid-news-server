import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Core Services
import '../offline_handler.dart';
import '../security/security_service.dart';
import '../security/secure_prefs.dart';
import '../utils/network_utils.dart';
import '../network_quality_manager.dart';
import '../services/app_network_service.dart';
import '../services/remote_config_service.dart';
import '../services/saved_articles_service.dart';
import '../services/article_scraper_service.dart';

// Features
import '../../features/profile/auth_service.dart';
import '../../features/tts/services/tts_manager.dart';
import '../../features/tts/services/tts_database.dart';
import '../../features/tts/services/audio_cache_manager.dart';

// Data
import '../../data/services/push_notification_service.dart';
import '../../data/repositories/news_repository.dart';
import '../../data/services/rss_service.dart';
import '../../data/services/hive_service.dart';

/// Global service locator instance
/// 
/// Usage:
/// ```dart
/// final authService = sl<AuthService>();
/// authService.login(...);
/// ```
final sl = GetIt.instance;

/// Initialize all dependencies
/// 
/// Call this once during app startup in main.dart:
/// ```dart
/// await setupDependencies();
/// runApp(MyApp());
/// ```
Future<void> setupDependencies() async {
  // ========================================
  // EXTERNAL DEPENDENCIES
  // ========================================
  
  // SharedPreferences - singleton
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);
  
  // Firebase instances - singletons
  sl.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  sl.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
  
  // ========================================
  // CORE UTILITIES (Truly Singleton)
  // ========================================
  
  // These are genuinely app-scoped singletons
  // ✅ Register existing singleton instances
  sl.registerLazySingleton<NetworkUtils>(() => NetworkUtils.instance);
  sl.registerLazySingleton<SecurePrefs>(() => SecurePrefs.instance);
  
  // ========================================
  // CORE SERVICES (Lazy Singleton)
  // ========================================
  
  sl.registerLazySingleton<OfflineHandler>(
    () => OfflineHandler(),
  );
  
  sl.registerLazySingleton<SecurityService>(
    () => SecurityService(),
  );
  
  sl.registerLazySingleton<NetworkQualityManager>(
    () => NetworkQualityManager(),
  );
  
  sl.registerLazySingleton<AppNetworkService>(
    () => AppNetworkService(),
  );
  
  sl.registerLazySingleton<RemoteConfigService>(
    () => RemoteConfigService(),
  );
  
  // ========================================
  // AUTHENTICATION
  // ========================================
  
  sl.registerLazySingleton<AuthService>(
    () => AuthService(),
  );
  
  // ========================================
  // FEATURE SERVICES
  // ========================================
  
  sl.registerLazySingleton<SavedArticlesService>(
    () => SavedArticlesService.instance,
  );
  
  sl.registerLazySingleton<ArticleScraperService>(
    () => ArticleScraperService.instance,
  );
  
  sl.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(),
  );
  
  // ========================================
  // TTS SERVICES
  // ========================================
  
  // ⚠️ TEMPORARY: TTS services remain as singletons due to circular dependency
  // Will migrate after resolving architecture issues
  // Access via TtsManager.instance, TtsDatabase.instance, AudioCacheManager.instance
  
  // ========================================
  // DATA LAYER
  // ========================================
  
  // Services - can be factories if stateless
  sl.registerFactory<RssService>(() => RssService());
  
  // Repositories
  sl.registerLazySingleton<NewsRepository>(
    () => NewsRepository(
      rssService: sl<RssService>(),
    ),
  );
  
  // ========================================
  // INITIALIZATION
  // ========================================
  
  // Initialize services that need async setup
  await _initializeAsyncServices();
}

/// Initialize services requiring async setup
Future<void> _initializeAsyncServices() async {
  // Initialize remote config
  await sl<RemoteConfigService>().initialize();
  
  // TTS Database initializes lazily on first access
  // Security service initializes via singleton pattern
}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await sl.reset();
}
