// lib/core/di/service_locator.dart
// ==================================
// DEPENDENCY INJECTION - SERVICE LOCATOR
// Provides centralized access to services
// ==================================

import 'package:flutter/foundation.dart';
import '../services/app_network_service.dart';
import '../services/remote_config_service.dart';
import '../security/ssl_pinning.dart';
import '../../data/services/rss_service.dart';
import '../../data/services/device_session_service.dart';
import '../../features/tts/services/tts_manager.dart';

/// Service Locator for Dependency Injection
/// 
/// Provides centralized access to all app services.
/// Initialize once at app startup.
class ServiceLocator {
  ServiceLocator._();
  static final ServiceLocator instance = ServiceLocator._();

  bool _initialized = false;

  // Services
  late final AppNetworkService networkService;
  late final RssService rssService;
  late final DeviceSessionService deviceSessionService;
  late final RemoteConfigService remoteConfigService;

  /// Initialize all services
  Future<void> initialize() async {
    if (_initialized) return;

    if (kDebugMode) {
      debugPrint('[ServiceLocator] Initializing services...');
    }

    // 1. Initialize synchronous/fast services
    rssService = RssService();
    deviceSessionService = DeviceSessionService();
    remoteConfigService = RemoteConfigService();
    networkService = AppNetworkService();

    // 2. Start async initializations in parallel
    // We await critical ones, but let non-critical ones run in background
    // SSL Pinning is critical for security
    await SSLPinning.initialize();

    // Network and RemoteConfig can init in parallel
    // We implement a fast timeout for startup critical path
    await Future.wait([
      networkService.initialize(),
      // Allow 0.5 seconds max for remote config to prevent splash hang
      remoteConfigService.initialize().timeout(
        const Duration(milliseconds: 500), 
        onTimeout: () => debugPrint('[ServiceLocator] Remote Config init timed out (using defaults)'),
      ),
    ]);

    // Initialize TTS Manager (Background Audio)
    TtsManager.instance.init();

    _initialized = true;

    if (kDebugMode) {
      debugPrint('[ServiceLocator] All services initialized');
    }
  }

  /// Get network service
  AppNetworkService get network => networkService;

  /// Get RSS service
  RssService get rss => rssService;

  /// Get device session service
  DeviceSessionService get deviceSession => deviceSessionService;
  
  /// Get push notification service
  // PushNotificationService get pushNotification => pushNotificationService;

  /// Get remote config service
  RemoteConfigService get remoteConfig => remoteConfigService;

  /// Dispose all services
  void dispose() {
    networkService.dispose();
    _initialized = false;
    
    if (kDebugMode) {
      debugPrint('[ServiceLocator] Services disposed');
    }
  }
}

/// Quick access to service locator
ServiceLocator get sl => ServiceLocator.instance;
