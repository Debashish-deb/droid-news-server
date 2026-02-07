import 'dart:async' show runZonedGuarded, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/sync/sync_orchestrator.dart'; 
import 'application/lifecycle/app_state_machine.dart'; 

// Riverpod providers
import 'presentation/providers/theme_providers.dart';
import 'platform/persistence/app_database.dart';

import 'core/providers.dart';
import 'presentation/providers/app_settings_providers.dart';
import 'presentation/providers/language_providers.dart';
import 'infrastructure/repositories/settings_repository_impl.dart';
import 'infrastructure/repositories/favorites_repository_impl.dart';
import 'infrastructure/sync/sync_service.dart';
import 'infrastructure/network/app_network_service.dart';
import 'core/utils/network_utils.dart';
import 'core/performance_config.dart';

// Legacy providers (for widgets that still need specialized methods)
import 'core/premium_service.dart' as legacy_premium;

// Core
import 'core/routes.dart';
import 'core/splash_service.dart';
import 'core/theme.dart';
import 'core/utils/error_handler.dart';
import 'bootstrap/di/injection_container.dart' as di; 
import 'core/telemetry/observability_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/widgets/session_validator.dart';
import 'domain/facades/auth_facade.dart';
import 'core/services/background_service.dart';
import 'main_helper.dart';

import 'core/bootstrap/firebase_bootstrapper.dart';
import 'core/bootstrap/device_trust_bootstrapper.dart';

late SharedPreferences _prefs;
late legacy_premium.PremiumService _premiumService;

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load();

      // 1. Critical Base Services (Firebase, DI)
      final firebaseBootstrapper = FirebaseBootstrapper();
      await firebaseBootstrapper.initialize(fetchRemoteConfig: false);
      await di.configureDependencies(); 
      
      _prefs = di.sl<SharedPreferences>();
      final observability = di.sl<ObservabilityService>();
      
      observability.logEvent('app_start_init');
      Future<void> safeBackground(Future<void> future, String reason) async {
        try {
          await future;
        } catch (e, stack) {
          await observability.recordError(e, stack, reason: reason);
        }
      }

      // 3. Create Container for early initialization
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(_prefs),
          settingsRepositoryProvider.overrideWith((ref) => SettingsRepositoryImpl(_prefs)),
          favoritesRepositoryProvider.overrideWith((ref) => FavoritesRepositoryImpl(_prefs, di.sl<SyncService>(), di.sl<AppDatabase>())),
        ],
      );

      // 4. Parallel Orchestrated Bootstrap (keep lightweight)
      try {
        await Future.wait([
          container.read(themeProvider.notifier).initialize(),
          container.read(languageProvider.notifier).initialize(),
        ]);
      } catch (e) {
        observability.recordError(e, StackTrace.current, reason: 'Orchestrated Bootstrap Failure');
        // Continue anyway if non-fatal, or handle hard exit
      }

      final initialRoute = await SplashService(prefs: _prefs).resolveInitialRoute();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: MyApp(initialRoute: initialRoute),
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          safeBackground(
            firebaseBootstrapper.initializeRemoteConfig(),
            'RemoteConfig init failed',
          ),
        );
        unawaited(
          safeBackground(
            di.sl<AppNetworkService>().initialize(),
            'Network service init failed',
          ),
        );
        unawaited(
          safeBackground(
            di.sl<NetworkUtils>().initialize(),
            'Network utils init failed',
          ),
        );
        unawaited(
          safeBackground(
            DeviceTrustBootstrapper.withContainer(container).initialize(),
            'Device trust init failed',
          ),
        );
        unawaited(
          safeBackground(
            BackgroundService.initialize(),
            'Background service init failed',
          ),
        );

        _premiumService = di.sl<legacy_premium.PremiumService>();
        unawaited(
          safeBackground(
            _premiumService.loadStatus(),
            'Premium status load failed',
          ),
        );
        
        final authService = di.sl<AuthFacade>();
        unawaited(
          safeBackground(
            authService.init(),
            'Auth init failed',
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
    
    try {
      SyncOrchestrator().registerAppLifecycleNotifier(lifeCycle);
    } catch (e) {
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
