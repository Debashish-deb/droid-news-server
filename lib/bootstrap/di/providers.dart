import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network_quality_manager.dart' show NetworkQualityManager;
import '../../core/offline_handler.dart' show OfflineHandler;
import '../../core/security/security_service.dart' show SecurityService;
import '../../domain/facades/auth_facade.dart';
import '../../presentation/features/tts/services/tts_database.dart' show TtsDatabase;
import '../../presentation/features/tts/services/tts_manager.dart' show TtsManager;
import 'injection_container.dart';

import '../../infrastructure/network/app_network_service.dart';
import '../../infrastructure/services/remote_config_service.dart';

// Feature Services

// Data
import '../../domain/repositories/news_repository.dart';

/// Riverpod providers for get_it managed dependencies
/// 
/// Usage in widgets:
/// ```dart
/// final ttsManager = ref.read(ttsManagerProvider);
/// ttsManager.speakArticle(...);
/// ```

// ========================================
// CORE SERVICES
// ========================================

final offlineHandlerProvider = Provider<OfflineHandler>((ref) {
  return sl<OfflineHandler>();
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  return sl<SecurityService>();
});

final networkQualityProvider = Provider<NetworkQualityManager>((ref) {
  return sl<NetworkQualityManager>();
});

final appNetworkServiceProvider = Provider<AppNetworkService>((ref) {
  return sl<AppNetworkService>();
});

final remoteConfigProvider = Provider<RemoteConfigService>((ref) {
  return sl<RemoteConfigService>();
});

// ========================================
// AUTHENTICATION
// ========================================

final authServiceProvider = Provider<AuthFacade>((ref) {
  return sl<AuthFacade>();
});

// ========================================
// TTS SERVICES
// ========================================

final ttsManagerProvider = Provider<TtsManager>((ref) {
  return sl<TtsManager>();
});

final ttsDatabaseProvider = Provider<TtsDatabase>((ref) {
  return sl<TtsDatabase>();
});

// ========================================
// DATA LAYER
// ========================================

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return sl<NewsRepository>();
});

// ========================================
// STREAM PROVIDERS (for reactive data)
// ========================================

/// Stream of authentication state changes
final authStateProvider = StreamProvider<bool>((ref) {
  return Stream.value(false);
});
