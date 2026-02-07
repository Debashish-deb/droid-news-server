import 'package:get_it/get_it.dart';

// Core Services
import '../../core/telemetry/observability_service.dart';
import '../../infrastructure/services/remote_config_service.dart' show RemoteConfigService;
import '../../infrastructure/services/assets_data_loader.dart';
import 'package:injectable/injectable.dart';
import '../../core/telemetry/structured_logger.dart' show StructuredLogger;
import 'injection_container.config.dart';

// Platform Core Integration

// Features


// Data



/// Global service locator instance
/// 
/// Usage:
/// ```dart
/// final authService = sl<AuthFacade>();
/// authService.login(...);
/// ```
final sl = GetIt.instance;

@InjectableInit(
  preferRelativeImports: true,
)
Future<void> configureDependencies() async {
  // Register ObservabilityService FIRST if not already registered by injectable
  // This ensures ErrorHandler can always access it, even if injectable fails
  if (!sl.isRegistered<ObservabilityService>()) {
    sl.registerLazySingleton<ObservabilityService>(() => ObservabilityService());
  }
  
  await sl.init();
  
  await _initializeAsyncServices();
}

/// Initialize services requiring async setup
Future<void> _initializeAsyncServices() async {
  await sl<RemoteConfigService>().initialize();
  
  // Pre-load heavy assets in background immediately
  AssetsDataLoader().loadData().then((_) {
    final logger = StructuredLogger();
    logger.info('✅ Assets pre-loaded in background');
  }).catchError((e) {
    final logger = StructuredLogger();
    logger.error('⚠️ Assets pre-load failed', e);
  });
}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await sl.reset();
}
