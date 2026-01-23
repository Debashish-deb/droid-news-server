import 'dart:async' show runZonedGuarded;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// import 'package:firebase_app_check/firebase_app_check.dart'; // Skipped: version conflict
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy;

// Riverpod providers
import 'core/services/theme_providers.dart';
import 'core/services/favorites_providers.dart';
import 'core/services/favorites_service.dart';
import 'core/splash_service.dart' show resolveInitialRoute;
import 'presentation/providers/shared_providers.dart';
import 'presentation/providers/language_providers.dart';

// Legacy providers (for widgets that still need specialized methods)
import 'core/theme_provider.dart' as legacy_theme;

import 'core/language_provider.dart' as legacy_lang;
import 'core/tab_change_notifier.dart' as legacy_tab;
import 'core/app_settings_service.dart' as legacy_settings;
import 'core/premium_service.dart' as legacy_premium;
import 'core/sync_service.dart';

// Core
import 'core/routes.dart';
import 'core/splash_service.dart';
import 'core/theme.dart';
import 'core/utils/error_handler.dart';
import 'core/di/injection_container.dart'; // ✅ NEW: get_it DI
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'widgets/session_validator.dart';

late SharedPreferences _prefs;
late legacy_premium.PremiumService _premiumService;

Future<void> main() async {
  // Run app in error zone to catch all errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load();

      // Initialize Firebase safely (prevent duplicate initialization)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        Firebase.app(); // Ensure default app exists
      }

      // Firebase App Check - Skipped due to dependency conflict
      // TODO: Re-enable when firebase_app_check is compatible with firebase_analytics
      // await FirebaseAppCheck.instance.activate(
      //   androidProvider: AndroidProvider.playIntegrity,
      //   appleProvider: AppleProvider.deviceCheck,
      // );

      // Initialize Crashlytics with enhanced reporting
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      // Non-fatal error handling
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Initialize core services
      await ErrorHandler.initialize();
      await setupDependencies(); // ✅ NEW: get_it DI container
      _prefs = await SharedPreferences.getInstance();

      // Initialize legacy PremiumService (fast local check)
      _premiumService = legacy_premium.PremiumService(prefs: _prefs);
      await _premiumService.loadStatus();

      // Defer heavy initializations to SplashScreen
      // - OfflineService
      // - NotificationService
      // - MobileAds
      // - Analytics

      final initialRoute =
          await SplashService(prefs: _prefs).resolveInitialRoute();

      // ProviderScope at root level with all overrides
      runApp(
        ProviderScope(
          overrides: [
            // Core Riverpod providers
            sharedPreferencesProvider.overrideWithValue(_prefs),
            themeProvider.overrideWith((ref) => ThemeNotifier(_prefs)),
            languageProvider.overrideWith((ref) => LanguageNotifier(_prefs)),
            favoritesProvider.overrideWith(
              (ref) => FavoritesNotifier(_prefs, SyncService()),
            ),
          ],
          child: MyApp(initialRoute: initialRoute),
        ),
      );
    },
    (error, stack) {
      // Catch errors outside Flutter framework
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
    _router = AppRouter.createRouter(initialLocation: widget.initialRoute);
  }

  @override
  Widget build(BuildContext context) {
    // Watch Riverpod providers for theme and locale
    final themeState = ref.watch(themeProvider);
    final localeState = ref.watch(languageProvider);

    // Wrap with legacy MultiProvider for widgets that still use legacy providers
    return legacy.MultiProvider(
      providers: [
        // SharedPreferences for legacy access
        legacy.Provider<SharedPreferences>.value(value: _prefs),
        // ThemeProvider for floatingTextStyle and other methods
        legacy.ChangeNotifierProvider(
          create: (_) => legacy_theme.ThemeProvider(_prefs),
        ),
        // LanguageProvider
        legacy.ChangeNotifierProvider(
          create: (_) => legacy_lang.LanguageProvider(),
        ),

        // TabChangeNotifier for navigation
        legacy.ChangeNotifierProvider(
          create: (_) => legacy_tab.TabChangeNotifier(),
        ),
        // AppSettingsService for SettingsScreen
        legacy.ChangeNotifierProvider(
          create: (_) => legacy_settings.AppSettingsService(SyncService()),
        ),
        // PremiumService for premium features
        legacy.ChangeNotifierProvider<legacy_premium.PremiumService>(
          create: (_) => _premiumService,
        ),
      ],
      child: SessionValidator(
        child: MaterialApp.router(
          title: dotenv.env['APP_NAME'] ?? 'BD News Reader',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeState.themeMode,
          locale: localeState.locale,
          supportedLocales: const [Locale('en'), Locale('bn')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}
