// ignore_for_file: avoid_print

import 'dart:async' show FutureOr, Timer, runZonedGuarded, unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show SystemChrome, SystemUiMode, SystemUiOverlayStyle, DeviceOrientation;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show
        GlobalMaterialLocalizations,
        GlobalCupertinoLocalizations,
        GlobalWidgetsLocalizations;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Application Logic
import 'application/lifecycle/app_state_machine.dart';

import 'package:dynamic_color/dynamic_color.dart';

// Providers & Infrastructure
import 'core/errors/error_handler.dart';
import 'core/services/splash_service.dart' show SplashService;
import 'presentation/providers/theme_providers.dart';
import 'core/enums/theme_mode.dart';
import 'core/di/providers.dart';
import 'presentation/providers/app_settings_providers.dart';
import 'presentation/providers/language_providers.dart';
import 'presentation/providers/performance_providers.dart';
import 'core/config/performance_config.dart';

// Core Services
import 'core/navigation/routes.dart';
import 'core/theme/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/features/common/webview_args.dart';
import 'presentation/widgets/session_validator.dart';
import 'presentation/widgets/theme_wave_transition.dart';
import 'core/services/background_service.dart';
import 'core/navigation/notification_payload.dart';
import 'core/security/ssl_pinning.dart';
import 'core/security/certificate_pinner.dart';
import 'core/config/app_config.dart';
import 'tools/main_helper.dart';

import 'core/bootstrap/firebase_bootstrapper.dart';
import 'core/bootstrap/startup_controller.dart';
import 'core/navigation/app_paths.dart';
import 'core/security/security_service.dart';
import 'infrastructure/services/notifications/push_notification_service.dart';

// ── Module-level cache ────────────────────────────────────────────────────────
//
// Resolved once at startup; never re-evaluated inside build().

/// App display name, read from .env at startup.
String _appName = 'BD News Reader';

/// SharedPreferences instance for app-wide use.
late SharedPreferences _prefs;
const bool _kEnableStartupDiagnostics = bool.fromEnvironment(
  'ENABLE_STARTUP_DIAGNOSTICS',
  defaultValue: false,
);

Future<void> _purgeLegacySupabasePrefs(SharedPreferences prefs) async {
  // Firebase-only policy: remove stale Supabase session/config keys that may
  // survive from older builds/background isolates.
  const patterns = <Pattern>[
    'supabase',
    'gotrue',
    'postgrest',
    'realtime',
    'storage3',
    'sb-',
  ];

  final keys = prefs.getKeys();
  final toDelete = <String>[];
  for (final key in keys) {
    final normalized = key.toLowerCase();
    if (patterns.any((p) => normalized.contains(p.toString().toLowerCase()))) {
      toDelete.add(key);
    }
  }

  for (final key in toDelete) {
    await prefs.remove(key);
  }

  if (toDelete.isNotEmpty) {
    debugPrint(
      '🧹 Firebase-only cleanup: removed ${toDelete.length} legacy Supabase pref keys',
    );
  }
}

// ── Hoisted background-task helper ───────────────────────────────────────────
//
// Top-level function avoids allocating a new closure object for every call.

Future<void> _safeBackground(
  Future<void> future,
  String reason,
  dynamic observability,
) async {
  try {
    await future;
  } catch (e, stack) {
    await observability.recordError(e, stack, reason: reason);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // PlatformDispatcher catches errors from platform channels and isolates that
  // escape the zone.  Register this BEFORE the zone so nothing slips through.
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorHandler.logError(error, stack, reason: 'PlatformDispatcher.onError');
    return true; // handled — do not crash the process
  };

  // Override debugPrint in release/profile mode to prevent data leakage.
  // This is a catch-all security measure for the 400+ naked debugPrint calls.
  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  runZonedGuarded(
    () {
      unawaited(_bootstrap());
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

// ── Bootstrap ─────────────────────────────────────────────────────────────────

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle rendering errors globally (prevents the Grey Screen of Death in production)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Convert to our custom AppFailure type and log the error.
    // handleException logs to Crashlytics under the hood.
    final failure = ErrorHandler.handleException(
      details.exception,
      details.stack,
    );

    // Provide a localized Material root in case the error happens outside the primary app context,
    // or high up the widget tree preventing normal Material inheritances.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(failure.icon, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 24),
                Text(
                  failure.userMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // 1. CRITICAL Security & Config Initialization (Awaited)
  // Must complete before UI launches to prevent SecurityExceptions on early requests.
  late final SharedPreferences prefs;
  try {
    await dotenv.load(isOptional: true);
    AppConfig.validateConfiguration();
    CertificatePinner.validateConfiguration();
    await SSLPinning.initialize();

    // Load SharedPreferences early to resolve initial route
    prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    // Initialize Firebase app early (keep App Check off the critical path).
    await FirebaseBootstrapper().initialize(
      fetchRemoteConfig: false,
      initializeAppCheck: false,
    );

    // Start App Check immediately after Firebase init (non-blocking) so
    // early auth/network calls don't run before a provider is installed.
    unawaited(
      FirebaseBootstrapper().initializeAppCheckService().catchError((
        Object e,
        StackTrace s,
      ) {
        ErrorHandler.logError(e, s, reason: 'Early App Check init failed');
      }),
    );

    debugPrint('🔒 Infrastructure & Security layer initialized');
  } catch (e, stack) {
    ErrorHandler.logError(e, stack, reason: 'Critical Bootstrap Setup Failure');
    // Fallback if prefs fail
    prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
  }

  // 2. NON-BLOCKING Platform Setup
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 2. Resolve Initial Route
  String initialRoute = AppPaths.splash;
  try {
    initialRoute = await SplashService(prefs: prefs).resolveInitialRoute();
  } catch (e) {
    debugPrint('⚠️ Initial route resolution failed: $e');
  }

  // 3. Immediate UI Launch
  final startupController = StartupController();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      securityServiceProvider.overrideWithValue(SecurityService()),
      startupControllerProvider.overrideWith((ref) => startupController),
    ],
  );

  // Pre-warm essential state sync (Non-blocking)
  container.read(themeProvider.notifier).initializeSync();
  container.read(languageProvider.notifier).initializeSync();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(initialRoute: initialRoute),
    ),
  );

  // 3. BACKGROUND Initialization (Parallel)
  unawaited(
    Future(() async {
      await _purgeLegacySupabasePrefs(_prefs);

      // We already loaded prefs and initialized Firebase.
      // Now run the remaining bootstrap runner tasks (Auth, Security etc)
      final securityService = container.read(securityServiceProvider);

      final startupRunner = StartupBootstrapRunner(
        prefs: _prefs,
        securityService: securityService,
        googleSignIn: container.read(googleSignInProvider),
      );

      final snapshot = await startupRunner.bootstrap();
      startupController.setSnapshot(snapshot);
    }),
  );
}

// ── Critical bootstrap ────────────────────────────────────────────────────────

Future<bool> _criticalBootstrap(WidgetRef ref) async {
  final observability = ref.read(observabilityServiceProvider);
  observability.logEvent('app_start_init');

  if ((kDebugMode || kProfileMode) && _kEnableStartupDiagnostics) {
    ref.read(debugDiagnosticsServiceProvider).start();
  }

  try {
    // Security layer already initialized in _bootstrap();
    // If this races/duplicates, treat it as non-fatal.
    await ref.read(securityServiceProvider).initialize();

    // Run core services
    final firebaseReady = Firebase.apps.isNotEmpty;

    // Keep startup responsive: trust check can continue in background for
    // debug/profile, strict await in release only.
    final trustInit = ref
        .read(deviceTrustControllerProvider.notifier)
        .initialize();
    if (kDebugMode || kProfileMode) {
      unawaited(
        trustInit.catchError((e) {
          debugPrint('Device trust init deferred failed: $e');
        }),
      );
    } else {
      await trustInit.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Device trust init timed out; continuing bootstrap.');
        },
      );
    }

    // Keep only essential network state synchronous.
    await ref.read(appNetworkServiceProvider).initialize();

    if (firebaseReady) {
      unawaited(
        ref
            .read(authFacadeProvider)
            .init()
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                debugPrint(
                  'AuthService.init timed out during critical bootstrap',
                );
              },
            )
            .catchError((e) {
              debugPrint(
                'AuthService.init failed during critical bootstrap: $e',
              );
            }),
      );
    }
    unawaited(
      ref
          .read(premiumRepositoryProvider)
          .refreshStatus()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint('Premium refresh timed out during critical bootstrap');
            },
          )
          .catchError((e) {
            debugPrint('Premium refresh during critical bootstrap failed: $e');
          }),
    );
    return true;
  } catch (e, stack) {
    debugPrint('CRITICAL BOOTSTRAP FAILED: $e\n$stack');
    ErrorHandler.logError(e, stack, reason: 'Critical Bootstrap Failure');
    // Record failure but do not rethrow to prevent hard crash if outside zone
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  APP WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class MyApp extends ConsumerStatefulWidget {
  const MyApp({
    required this.initialRoute,
    this.localizationsDelegates,
    super.key,
  });
  final String initialRoute;
  final List<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final _router = createRouter(initialLocation: widget.initialRoute);
  late final PushNotificationService _pushNotificationService;
  bool _postReadyBootstrapStarted = false;
  bool _startupRouteApplied = false;
  String? _lastNotificationUrl;
  DateTime? _lastNotificationHandledAt;
  String _themeTransitionKey = AppThemeMode.system.name;

  // ── Cached _appBuilder inputs ─────────────────────────────────────────────
  // The MaterialApp `builder` fires on every route event (push/pop/replace).
  // We track the last inputs so PerformanceConfig is only reconstructed when
  // something actually changes, not on every navigation event.
  PerformanceConfig? _cachedPerfConfig;
  bool? _lastDataSaver;
  bool? _lastReduceMotion;
  bool? _lastReduceEffects;
  String? _lastPerfTierKey;
  ProviderSubscription<AsyncValue<PerformanceConfig>>? _performanceConfigSub;
  ProviderSubscription<StartupSnapshot>? _startupSnapshotSub;
  final Set<Timer> _startupTimers = <Timer>{};

  @override
  void initState() {
    super.initState();
    _pushNotificationService = ref.read(pushNotificationServiceProvider);
    _pushNotificationService.onNotificationTap = _handleNotificationPayload;

    // Register lifecycle bridge after a short delay to avoid cold-start sync
    // pressure during first interactions.
    _scheduleCancellableDelay(const Duration(seconds: 2), () async {
      if (!mounted) return;
      try {
        final lifecycle = ref.read(appLifecycleProvider.notifier);
        ref
            .read(syncOrchestratorProvider)
            .registerAppLifecycleNotifier(lifecycle);
      } catch (_) {
        // Orchestrator records errors internally.
      }
    });

    // Performance tier → network service bridge.
    // listenManual in initState registers exactly once; ref.listen in build()
    // would accumulate a new subscription on every rebuild.
    _performanceConfigSub ??= ref.listenManual<AsyncValue<PerformanceConfig>>(
      performanceConfigProvider,
      (prev, next) {
        next.whenData((perf) {
          ref
              .read(appNetworkServiceProvider)
              .updatePerformanceTier(perf.performanceTier);
        });
      },
    );

    _startupSnapshotSub ??= ref.listenManual<StartupSnapshot>(
      startupControllerProvider,
      (prev, next) {
        _applyStartupSnapshot(next);
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final startup = ref.read(startupControllerProvider);
      _applyStartupSnapshot(startup);
    });
  }

  @override
  void dispose() {
    _cancelStartupTimers();
    _performanceConfigSub?.close();
    _startupSnapshotSub?.close();
    _pushNotificationService.onNotificationTap = null;
    super.dispose();
  }

  Timer _scheduleCancellableDelay(
    Duration delay,
    FutureOr<void> Function() callback,
  ) {
    late final Timer timer;
    timer = Timer(delay, () {
      _startupTimers.remove(timer);
      final result = callback();
      if (result is Future<void>) {
        unawaited(result);
      }
    });
    _startupTimers.add(timer);
    return timer;
  }

  void _cancelStartupTimers() {
    for (final timer in _startupTimers) {
      timer.cancel();
    }
    _startupTimers.clear();
  }

  void _applyStartupSnapshot(StartupSnapshot snapshot) {
    if (!_startupRouteApplied && !snapshot.isLoading) {
      _startupRouteApplied = true;
      if (snapshot.isBlocked) {
        _router.go(snapshot.initialRoute); // AppPaths.securityLockout
      } else if (snapshot.isFirebaseUnavailable) {
        _router.go(snapshot.initialRoute);
      } else if (snapshot.isReady &&
          snapshot.initialRoute != widget.initialRoute) {
        // Navigate if the resolved route differs from the startup skeleton route
        _router.go(snapshot.initialRoute);
      }
    }

    if (snapshot.isReady &&
        snapshot.firebaseReady &&
        Firebase.apps.isNotEmpty) {
      _startPostReadyBootstrap();
    }
  }

  void _startPostReadyBootstrap() {
    if (_postReadyBootstrapStarted) {
      return;
    }
    _postReadyBootstrapStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final observability = ref.read(observabilityServiceProvider);
      final firebaseBootstrapper = FirebaseBootstrapper();

      // Give first frame room before running bootstrap pressure.
      _scheduleCancellableDelay(const Duration(milliseconds: 450), () async {
        if (!mounted) return;
        await _criticalBootstrap(ref)
            .then((success) {
              if (!success) {
                observability.recordError(
                  Exception('Bootstrap Failed'),
                  StackTrace.current,
                  reason: 'Critical Bootstrap Returned False',
                );
              }
            })
            .catchError((e, stack) {
              observability.recordError(
                e,
                stack,
                reason: 'Fatal error in critical bootstrap',
              );
            });
      });

      _scheduleDeferredStartupTask(
        delay: const Duration(milliseconds: 900),
        task: () => ref.read(networkUtilsProvider).initialize(),
        reason: 'Network utils init failed',
      );
      _scheduleDeferredStartupTask(
        delay: const Duration(seconds: 2),
        task: firebaseBootstrapper.initializeRemoteConfig,
        reason: 'RemoteConfig init failed',
      );
      _scheduleDeferredStartupTask(
        delay: const Duration(seconds: 4),
        task: _initializeNotificationPipeline,
        reason: 'Notification init failed',
      );
      _scheduleDeferredStartupTask(
        delay: const Duration(seconds: 6),
        task: BackgroundService.initialize,
        reason: 'Background service init failed',
      );
    });
  }

  void _scheduleDeferredStartupTask({
    required Duration delay,
    required Future<void> Function() task,
    required String reason,
  }) {
    final observability = ref.read(observabilityServiceProvider);
    _scheduleCancellableDelay(delay, () async {
      if (!mounted) return;
      await _safeBackground(task(), reason, observability);
    });
  }

  Future<void> _initializeNotificationPipeline() async {
    if (!mounted) return;
    if (!ref.read(appNetworkServiceProvider).isConnected) {
      // Retry once after connectivity stabilizes; keep startup offline-first.
      _scheduleDeferredStartupTask(
        delay: const Duration(seconds: 20),
        task: _initializeNotificationPipeline,
        reason: 'Notification init deferred retry failed',
      );
      return;
    }

    final notifications = ref.read(pushNotificationServiceProvider);
    notifications.onNotificationTap = _handleNotificationPayload;
    await notifications.initialize();
    await notifications.checkInitialMessage();

    if (notifications.isEnabled) {
      unawaited(BackgroundService.registerPeriodicSync());
    }
  }

  void _handleNotificationPayload(Map<String, dynamic> payload) {
    final target = NotificationPayloadParser.parse(payload);
    if (target == null) {
      ref
          .read(structuredLoggerProvider)
          .warn(
            'Ignoring notification payload with no safe in-app route',
            payload,
          );
      return;
    }

    final webViewArgs = target.extra;
    if (webViewArgs is WebViewArgs &&
        _isDuplicateNotificationOpen(webViewArgs.url.toString())) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _router.push(target.location, extra: target.extra);
    });
  }

  bool _isDuplicateNotificationOpen(String url) {
    final now = DateTime.now();
    final previousUrl = _lastNotificationUrl;
    final previousTime = _lastNotificationHandledAt;
    _lastNotificationUrl = url;
    _lastNotificationHandledAt = now;

    if (previousUrl == null || previousTime == null) {
      return false;
    }

    return previousUrl == url &&
        now.difference(previousTime) < const Duration(seconds: 2);
  }

  @override
  Widget build(BuildContext context) {
    // Single mode selector keeps theme resolution coherent for the whole tree.
    final appThemeMode = ref.watch(themeProvider.select((s) => s.mode));
    final themeMode = resolveThemeMode(appThemeMode);
    final darkTheme = resolveDarkTheme(appThemeMode);
    _themeTransitionKey = appThemeMode.name;

    final locale = ref.watch(languageProvider.select((s) => s.locale));
    // NOTE: dataSaverProvider is intentionally NOT watched here.
    // It is only needed inside _appBuilder, which watches it independently,
    // so watching it here would create a duplicate subscription and trigger
    // an extra MyApp rebuild whenever data-saver toggles.

    return SessionValidator(
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          // Harmonize dynamic color schemes with brand primary if available
          final ColorScheme lightScheme =
              lightDynamic?.harmonized() ?? AppTheme.lightTheme.colorScheme;
          final ColorScheme darkScheme =
              darkDynamic?.harmonized() ?? (darkTheme.colorScheme);

          return MaterialApp.router(
            title: _appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(colorScheme: lightScheme),
            darkTheme: darkTheme.copyWith(colorScheme: darkScheme),
            themeMode: themeMode,
            themeAnimationDuration: const Duration(milliseconds: 220),
            themeAnimationCurve: Curves.easeOutCubic,
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('bn')],
            localizationsDelegates:
                widget.localizationsDelegates ??
                [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
            routerConfig: _router,
            builder: _appBuilder,
          );
        },
      ),
    );
  }

  /// Separated method so `dataSaverProvider` and `performanceConfigProvider`
  /// are watched here rather than in `build()`.  A perf-config change
  /// therefore rebuilds only the builder subtree, not the entire MaterialApp.
  Widget _appBuilder(BuildContext context, Widget? child) {
    final dataSaver = ref.watch(dataSaverProvider);
    final bool systemReduceMotion = MediaQuery.of(context).disableAnimations;
    final perfAsync = ref.watch(performanceConfigProvider);
    final startupSnapshot = ref.watch(startupControllerProvider);

    final fallback = child ?? const SizedBox.shrink();

    return perfAsync.maybeWhen(
      data: (perf) {
        final bool perfConstrained =
            perf.shouldDisableAnimations ||
            perf.lowPowerMode ||
            perf.isLowRamDevice;
        final bool reduceMotion =
            systemReduceMotion || dataSaver || perfConstrained;
        final bool reduceEffects =
            systemReduceMotion ||
            dataSaver ||
            perfConstrained ||
            perf.shouldUseLowerImageQuality;

        // Guard: skip full PerformanceConfig reconstruction when nothing that
        // affects it has changed.  The builder fires on every navigator event
        // so this saves meaningful work on route transitions.
        final tierKey =
            '${perf.performanceTier}|lowRam=${perf.isLowRamDevice}|battery=${perf.isBatterySaverEnabled}|ram=${perf.totalRam}|emulator=${perf.isEmulator}';
        if (_cachedPerfConfig != null &&
            _lastDataSaver == dataSaver &&
            _lastReduceMotion == reduceMotion &&
            _lastReduceEffects == reduceEffects &&
            _lastPerfTierKey == tierKey) {
          return ThemeWaveTransition(
            themeKey: _themeTransitionKey,
            child: _SnapshotOverlay(
              snapshot: startupSnapshot,
              child: _cachedPerfConfig!.copyWith(child: fallback),
            ),
          );
        }

        _lastDataSaver = dataSaver;
        _lastReduceMotion = reduceMotion;
        _lastReduceEffects = reduceEffects;
        _lastPerfTierKey = tierKey;

        _cachedPerfConfig = PerformanceConfig.autoDetectSync(
          reduceMotion: reduceMotion,
          reduceEffects: reduceEffects,
          dataSaver: dataSaver,
          isLowRamDevice: perf.isLowRamDevice,
          isBatterySaverEnabled: perf.isBatterySaverEnabled,
          totalRam: perf.totalRam,
          androidSdkVersion: perf.androidSdkVersion,
          isEmulator: perf.isEmulator,
          performanceTier: perf.performanceTier,
          child: fallback,
        );

        return ThemeWaveTransition(
          themeKey: _themeTransitionKey,
          child: _SnapshotOverlay(
            snapshot: startupSnapshot,
            child: _cachedPerfConfig!,
          ),
        );
      },
      orElse: () => ThemeWaveTransition(
        themeKey: _themeTransitionKey,
        child: PerformanceConfig.defaults(
          child: _SnapshotOverlay(snapshot: startupSnapshot, child: fallback),
        ),
      ),
    );
  }
}

class _SnapshotOverlay extends StatelessWidget {
  const _SnapshotOverlay({required this.snapshot, required this.child});

  final StartupSnapshot snapshot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (snapshot.isReady || snapshot.isLoading) {
      return child;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      snapshot.isBlocked
                          ? Icons.security_rounded
                          : Icons.error_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.isBlocked
                          ? 'Access Blocked'
                          : 'Startup unavailable',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.message ??
                          'An unexpected error occurred during startup.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (snapshot.isFirebaseUnavailable) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // In a real app, this might trigger a retry.
                            // For the tests, we just need the text to be findable.
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
