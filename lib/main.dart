import 'dart:async' show runZonedGuarded, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Application Logic
import 'application/sync/sync_orchestrator.dart'; 
import 'application/lifecycle/app_state_machine.dart'; 

// Providers & Infrastructure
import 'core/utils/error_handler.dart' as ErrorHandler;
import 'presentation/providers/theme_providers.dart';
import 'platform/persistence/app_database.dart';
import 'core/di/providers.dart';
import 'presentation/providers/app_settings_providers.dart';
import 'presentation/providers/language_providers.dart';
import 'infrastructure/repositories/settings_repository_impl.dart';
import 'infrastructure/repositories/favorites_repository_impl.dart';
import 'infrastructure/sync/sync_service.dart';
import 'infrastructure/network/app_network_service.dart';
import 'core/utils/network_utils.dart';
import 'core/performance_config.dart';

// Core Services
import 'domain/repositories/premium_repository.dart';
import 'core/routes.dart';
import 'core/splash_service.dart';
import 'core/theme.dart';
import 'core/utils/error_handler.dart';
import 'core/telemetry/observability_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/widgets/session_validator.dart';
import 'domain/facades/auth_facade.dart';
import 'core/services/background_service.dart';
import 'main_helper.dart';

import 'core/bootstrap/firebase_bootstrapper.dart';
// import 'core/bootstrap/device_trust_bootstrapper.dart'; // No longer needed in critical path initialization

late SharedPreferences _prefs;

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load();

      // 1. Critical Base Services (Firebase, DI)
      final firebaseBootstrapper = FirebaseBootstrapper();
      await firebaseBootstrapper.initialize(fetchRemoteConfig: false);
      _prefs = await SharedPreferences.getInstance();
      
      // 2. Resolve Observability (early for logging)
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(_prefs),
        ],
      );
      
      final observability = container.read(observabilityServiceProvider);
      observability.logEvent('app_start_init');

      // 2. Helper for logging background failures
      Future<void> safeBackground(Future<void> future, String reason) async {
        try {
          await future;
        } catch (e, stack) {
          await observability.recordError(e, stack, reason: reason);
        }
      }

      // 3. Container initialized above with SharedPreferences

      // 4. Critical Path Bootstrap (Awaited BEFORE other services)
      try {
        // First, ensure device trust is resolved
        await container.read(deviceTrustControllerProvider.notifier).initialize();
        
        // Then, proceed with other services in parallel
        await Future.wait([
          container.read(themeProvider.notifier).initialize(),
          container.read(languageProvider.notifier).initialize(),
          container.read(authFacadeProvider).init(),
          container.read(premiumRepositoryProvider).refreshStatus(),
          container.read(appNetworkServiceProvider).initialize(),
          container.read(networkUtilsProvider).initialize(),
        ]);
      } catch (e) {
        observability.recordError(e, StackTrace.current, reason: 'Critical Bootstrap Failure');
      }

      // 5. Resolve Initial Route (Now safe because Auth and Trust are initialized)
      final initialRoute = await SplashService(prefs: _prefs).resolveInitialRoute();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: MyApp(initialRoute: initialRoute),
        ),
      );

      // 6. Non-Critical / Background Tasks
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          safeBackground(
            firebaseBootstrapper.initializeRemoteConfig(),
            'RemoteConfig init failed',
          ),
        );
        unawaited(
          safeBackground(
            BackgroundService.initialize(),
            'Background service init failed',
          ),
        );
        unawaited(
          safeBackground(
            BackgroundService.registerPeriodicSync(),
            'Background sync registration failed',
          ),
        );
      });
    },
    (error, stack) {
      ErrorHandler.logError(
        error,
        stack,
        reason: 'Uncaught error in main zone',
      );
    },
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({required this.initialRoute, super.key});
  final String initialRoute;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter(initialLocation: widget.initialRoute);
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final localeState = ref.watch(languageProvider);
    final bool dataSaver = ref.watch(dataSaverProvider);
    
    final ThemeMode themeMode = resolveThemeMode(themeState.mode);
    final ThemeData darkTheme = resolveDarkTheme(themeState.mode);
    
    final lifeCycle = ref.watch(appLifecycleProvider.notifier);
    
    // Connect Lifecycle to Sync Orchestrator
    try {
      ref.read(syncOrchestratorProvider).registerAppLifecycleNotifier(lifeCycle);
    } catch (e) {
      // Logged internally by orchestrator
    }

    return SessionValidator(
      child: MaterialApp.router(
        title: dotenv.env['APP_NAME'] ?? 'BD News Reader',
        theme: AppTheme.lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        locale: localeState.locale,
        supportedLocales: const [Locale('en'), Locale('bn')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
        builder: (context, child) {
          final bool systemReduceMotion = MediaQuery.of(context).disableAnimations;
          final bool reduceMotion = systemReduceMotion || dataSaver;
          final bool reduceEffects = dataSaver || systemReduceMotion;

          return PerformanceConfig(
            reduceMotion: reduceMotion,
            reduceEffects: reduceEffects,
            dataSaver: dataSaver,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}