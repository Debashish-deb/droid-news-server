import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../di/injection_container.dart';

// Core Services
import '../offline_handler.dart';
import '../security/security_service.dart';
import '../network_quality_manager.dart';
import '../services/app_network_service.dart';
import '../services/remote_config_service.dart';

// Feature Services
import '../../features/profile/auth_service.dart';
import '../../features/tts/services/tts_manager.dart';
import '../../features/tts/services/tts_database.dart';

// Data
import '../../data/repositories/news_repository.dart';

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

final authServiceProvider = Provider<AuthService>((ref) {
  return sl<AuthService>();
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
  // This would connect to AuthService stream in real implementation
  return Stream.value(false);
});
