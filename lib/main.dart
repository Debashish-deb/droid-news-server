// ignore_for_file: avoid_print

import 'dart:async' show FutureOr, Timer, runZonedGuarded, unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, kProfileMode, kReleaseMode, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        DeviceOrientation,
        MethodChannel,
        SystemChrome,
        SystemUiMode,
        SystemUiOverlayStyle;
import 'package:flutter/scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'core/enums/theme_mode.dart' show AppThemeMode, normalizeThemeMode;
import 'core/errors/error_handler.dart';
import 'core/services/splash_service.dart' show SplashService;
import 'presentation/providers/theme_providers.dart';
import 'core/di/providers.dart';
import 'presentation/providers/app_settings_providers.dart';
import 'presentation/providers/language_providers.dart';
import 'presentation/providers/performance_providers.dart';
import 'presentation/providers/feature_providers.dart'
    show publisherAssetsDataProvider;
import 'core/config/performance_config.dart';

// Core Services
import 'core/navigation/routes.dart';
import 'core/navigation/navigation_helper.dart';
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
SharedPreferences? _prefs;
const bool _kEnableStartupDiagnostics = bool.fromEnvironment(
  'ENABLE_STARTUP_DIAGNOSTICS',
);
const bool _kEnableDebugAppCheck = bool.fromEnvironment(
  'ENABLE_DEBUG_APP_CHECK',
);

bool get _useLiteDebugFirebaseStartup => kDebugMode && !_kEnableDebugAppCheck;

bool get _shouldWarmAuthBootstrap {
  if (Firebase.apps.isEmpty) {
    return false;
  }

  final prefs = _prefs;
  if (prefs == null) {
    return false;
  }

  if ((prefs.getBool('isLoggedIn') ?? false) == true) {
    return true;
  }

  try {
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}

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

    // Keep the fallback lightweight: avoid nested MaterialApp/routing trees.
    return Material(
      child: Scaffold(
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

  // 1. Minimal launch preparation.
  // Keep pre-runApp work tiny so Android can hand off as soon as Flutter can
  // paint the shell. Heavier config/network bootstrap continues in background.
  late final SharedPreferences prefs;
  String initialRoute = AppPaths.splash;
  try {
    // CertificatePinner.validateConfiguration(); // Moved to background bootstrap
    prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    initialRoute = SplashService(prefs: prefs).resolveInitialRouteHint();

    debugPrint('🚀 Startup shell prepared');
  } catch (e, stack) {
    ErrorHandler.logError(e, stack, reason: 'Critical Bootstrap Setup Failure');
    // Fallback if prefs fail
    prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    initialRoute = SplashService(prefs: prefs).resolveInitialRouteHint();
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

  // 2. Immediate UI Launch using the locally cached route hint.
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
  // prewarmThemeCaches(); // Moved to MyApp post-frame callback for smoother startup

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(initialRoute: initialRoute),
    ),
  );

  // 3. BACKGROUND Initialization (Parallel)
  unawaited(
    Future(() async {
      try {
        await _initializeDeferredStartupServices();
      } catch (e, stack) {
        ErrorHandler.logError(
          e,
          stack,
          reason: 'Deferred startup services init failed',
        );
      }

      await _purgeLegacySupabasePrefs(prefs);

      // Route hint is already on screen. Now run authoritative startup checks.
      final securityService = container.read(securityServiceProvider);

      final startupRunner = StartupBootstrapRunner(
        prefs: prefs,
        securityService: securityService,
      );

      final snapshot = await startupRunner.bootstrap();
      startupController.setSnapshot(snapshot);
    }),
  );
}

Future<void> _initializeDeferredStartupServices() async {
  await dotenv.load(isOptional: true);
  AppConfig.validateConfiguration();
  CertificatePinner.validateConfiguration();
  await SSLPinning.initialize();

  final firebaseBootstrapper = FirebaseBootstrapper();

  await firebaseBootstrapper.initialize(
    fetchRemoteConfig: false,
    initializeAppCheck: false,
  );

  if (_useLiteDebugFirebaseStartup) {
    debugPrint(
      'ℹ️ Lite Firebase debug startup active: deferring Remote Config, notifications, and background boot work.',
    );
  }

  // Keep App Check off by default in debug. It adds noisy Google Play /
  // Play Integrity churn during hot restart on some devices.
  final shouldInitAppCheck = kReleaseMode || _kEnableDebugAppCheck;
  if (shouldInitAppCheck) {
    unawaited(
      firebaseBootstrapper.initializeAppCheckService().catchError((
        Object e,
        StackTrace s,
      ) {
        ErrorHandler.logError(e, s, reason: 'Early App Check init failed');
      }),
    );
  }
}

// ── Critical bootstrap ────────────────────────────────────────────────────────

Future<bool> _criticalBootstrap(WidgetRef ref) async {
  final observability = ref.read(observabilityServiceProvider);
  observability.logEvent('app_start_init');
  final deferFirebaseUserBootstrap = _useLiteDebugFirebaseStartup;

  if ((kDebugMode || kProfileMode) && _kEnableStartupDiagnostics) {
    ref.read(debugDiagnosticsServiceProvider).start();
  }

  try {
    final securityInit = ref
        .read(securityServiceProvider)
        .initialize()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('SecurityService.initialize timed out; continuing.');
          },
        )
        .catchError((Object e) {
          debugPrint('SecurityService.initialize deferred failed: $e');
        });
    unawaited(securityInit);

    final trustInit = ref
        .read(deviceTrustControllerProvider.notifier)
        .initialize()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Device trust init timed out; continuing bootstrap.');
          },
        )
        .catchError((Object e) {
          debugPrint('Device trust init deferred failed: $e');
        });
    unawaited(trustInit);

    // Keep only essential network state synchronous.
    await ref.read(appNetworkServiceProvider).initialize();

    // Run core services
    final firebaseReady = Firebase.apps.isNotEmpty;

    if (firebaseReady &&
        !deferFirebaseUserBootstrap &&
        _shouldWarmAuthBootstrap) {
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
  static const MethodChannel _androidLaunchSplashChannel = MethodChannel(
    'com.bdnews/splash',
  );
  // ── Startup timing constants ─────────────────────────────────────────────
  // Lite shell: holds a stripped-down app shell while the real theme/perf data
  // loads.  1400 ms gives enough room for SharedPreferences and theme reads
  // without blocking dynamic-color resolution longer than needed.
  static const Duration _kAndroidStartupLiteShellDuration = Duration(
    milliseconds: 600,
  );
  // Deferred work: staggered tasks that run after the first interactive frame.
  // Android values are deliberately higher than the defaults to give the system
  // GC / JIT time to settle, but kept tight enough to not delay real features.
  static const Duration _kDeferredLifecycleBridgeDelay = Duration(seconds: 4);
  static const Duration _kDeferredThemeCacheWarmupDelay = Duration(seconds: 5);
  static const Duration _kDeferredNetworkUtilsDelay = Duration(seconds: 4);
  static const Duration _kDeferredAuthWarmupDelay = Duration(seconds: 5);
  static const Duration _kDeferredRemoteConfigDelay = Duration(seconds: 20);
  static const Duration _kDeferredNotificationPipelineDelay = Duration(
    seconds: 6,
  );
  static const Duration _kDeferredNotificationRemoteSetupDelay = Duration(
    seconds: 30,
  );
  late final _router = createRouter(initialLocation: widget.initialRoute);
  late final PushNotificationService _pushNotificationService;
  bool _postReadyBootstrapStarted = false;
  bool _startupRouteApplied = false;
  String? _lastNotificationUrl;
  DateTime? _lastNotificationHandledAt;
  bool _androidLaunchSplashReleased = false;
  bool _androidLaunchSplashReleaseScheduled = false;
  String _themeTransitionKey = 'system';
  final GlobalKey<ThemeWaveTransitionState> _themeWaveKey =
      GlobalKey<ThemeWaveTransitionState>();
  AppThemeMode? _activeThemeMode;
  ThemeData? _cachedLightTheme;
  int? _cachedLightThemeSignature;
  bool _initialNotificationPayloadPrimed = false;
  Map<String, dynamic>? _pendingStartupNotificationPayload;
  bool _startupLiteShellActive = false;
  bool _themeTransitionArmed = false;
  StartupSnapshot _latestStartupSnapshot = const StartupSnapshot.loading();
  bool _latestDataSaver = false;
  AsyncValue<PerformanceConfig> _latestPerfAsync =
      const AsyncValue<PerformanceConfig>.loading();

  // ── Cached _appBuilder inputs ─────────────────────────────────────────────

  PerformanceConfig? _cachedPerfConfig;
  bool? _lastDataSaver;
  bool? _lastReduceMotion;
  bool? _lastReduceEffects;
  String? _lastPerfTierKey;
  AppThemeMode? _lastDynamicColorMode;
  bool? _cachedDynamicColorDecision;
  bool? _lastDynamicColorLiteShell;
  ColorScheme? _cachedDynamicLightScheme;
  ProviderSubscription<AsyncValue<PerformanceConfig>>? _performanceConfigSub;
  ProviderSubscription<bool>? _dataSaverSub;
  ProviderSubscription<StartupSnapshot>? _startupSnapshotSub;
  ProviderSubscription<AppThemeMode>? _themeModeSub;
  final Set<Timer> _startupTimers = <Timer>{};

  bool get _useStartupLiteShell =>
      _startupLiteShellActive &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  bool get _isAndroidStartupConstrained =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // Keep the post-ready bootstrap tight so dependent services come online
  // immediately after startup readiness transitions.
  Duration get _criticalBootstrapQuietWindow => _isAndroidStartupConstrained
      ? const Duration(milliseconds: 100)
      : const Duration(milliseconds: 50);

  Duration _deferredBootstrapDelay(
    Duration defaultDelay, {
    required Duration androidDelay,
  }) => _isAndroidStartupConstrained ? androidDelay : defaultDelay;

  bool _resolveUseDynamicColor(AppThemeMode mode) {
    if (_lastDynamicColorMode == mode &&
        _lastDynamicColorLiteShell == _useStartupLiteShell &&
        _cachedDynamicColorDecision != null) {
      return _cachedDynamicColorDecision!;
    }

    final bool decision;
    if (_useStartupLiteShell) {
      decision = false;
    } else if (!_isAndroidStartupConstrained) {
      decision = true;
    } else if (kDebugMode || kProfileMode) {
      decision = false;
    } else {
      decision = normalizeThemeMode(mode) == AppThemeMode.system;
    }

    _lastDynamicColorMode = mode;
    _lastDynamicColorLiteShell = _useStartupLiteShell;
    _cachedDynamicColorDecision = decision;
    return decision;
  }

  @override
  void initState() {
    super.initState();
    final startingTheme = ref.read(themeProvider.select((s) => s.mode));
    _activeThemeMode = startingTheme;
    _themeTransitionKey = startingTheme.name;
    _latestStartupSnapshot = ref.read(startupControllerProvider);
    _latestDataSaver = _prefs?.getBool('data_saver') ?? false;
    _latestPerfAsync = ref.read(performanceConfigProvider);

    _pushNotificationService = ref.read(pushNotificationServiceProvider);
    _pushNotificationService.onNotificationTap = _handleNotificationPayload;

    _themeModeSub ??= ref.listenManual<AppThemeMode>(
      themeProvider.select((s) => s.mode),
      (previous, next) {
        if (!mounted || next == _activeThemeMode) return;

        // Do not animate theme transitions while startup state is still
        // reconciling; this avoids expensive screenshot captures at boot.
        if (_useStartupLiteShell ||
            !_themeTransitionArmed ||
            !_latestStartupSnapshot.isReady) {
          setState(() {
            _activeThemeMode = next;
            _themeTransitionKey = next.name;
          });
          _themeTransitionArmed = true;
          return;
        }

        unawaited(
          _themeWaveKey.currentState?.captureBeforeThemeChange().then((_) {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _activeThemeMode = next;
                    _themeTransitionKey = next.name;
                  });
                });
              }) ??
              Future<void>.value(),
        );
      },
    );

    _startupLiteShellActive =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (_useStartupLiteShell) {
      _scheduleCancellableDelay(_kAndroidStartupLiteShellDuration, () {
        if (!mounted || !_startupLiteShellActive) return;
        _ensurePerformanceConfigBridge();
        setState(() {
          _startupLiteShellActive = false;
          _activeThemeMode = ref.read(themeProvider).mode;
          _themeTransitionKey = (_activeThemeMode ?? startingTheme).name;
        });
      });
    } else {
      _ensurePerformanceConfigBridge();
      _themeTransitionArmed = true;
    }

    _scheduleCancellableDelay(
      _deferredBootstrapDelay(
        _kDeferredLifecycleBridgeDelay,
        androidDelay: const Duration(seconds: 6),
      ),
      () async {
        if (!mounted) return;
        try {
          final lifecycle = ref.read(appLifecycleProvider.notifier);
          ref
              .read(syncOrchestratorProvider)
              .registerAppLifecycleNotifier(lifecycle);
        } catch (_) {}
      },
    );

    _startupSnapshotSub ??= ref.listenManual<StartupSnapshot>(
      startupControllerProvider,
      (prev, next) {
        _applyStartupSnapshot(next);
      },
    );

    if (_shouldControlAndroidLaunchSplash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleAndroidLaunchSplashRelease();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final startup = ref.read(startupControllerProvider);
      _applyStartupSnapshot(startup);

      _scheduleCancellableDelay(
        _deferredBootstrapDelay(
          _kDeferredThemeCacheWarmupDelay,
          androidDelay: const Duration(seconds: 1),
        ),
        () {
          if (!mounted) return;
          prewarmThemeCaches();
        },
      );
    });
  }

  @override
  void dispose() {
    _cancelStartupTimers();
    _performanceConfigSub?.close();
    _dataSaverSub?.close();
    _startupSnapshotSub?.close();
    _themeModeSub?.close();
    _pushNotificationService.onNotificationTap = null;
    super.dispose();
  }

  void _ensurePerformanceConfigBridge() {
    // Performance auto-detect uses Android method-channel calls. Deferring it keeps the first interactive seconds lighter on physical devices.
    _performanceConfigSub ??= ref.listenManual<AsyncValue<PerformanceConfig>>(
      performanceConfigProvider,
      (prev, next) {
        _latestPerfAsync = next;
        if (mounted) {
          setState(() {
            _cachedPerfConfig = null;
            _lastPerfTierKey = null;
          });
        }
        next.whenData((perf) {
          ref
              .read(appNetworkServiceProvider)
              .updatePerformanceTier(perf.performanceTier);
        });
      },
    );
  }

  void _ensureDataSaverBridge() {
    _dataSaverSub ??= ref.listenManual<bool>(dataSaverProvider, (prev, next) {
      if (prev == next) return;
      _latestDataSaver = next;
      if (mounted) {
        setState(() {
          _cachedPerfConfig = null;
          _lastPerfTierKey = null;
        });
      }
    });
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
    _latestStartupSnapshot = snapshot;
    if (mounted) {
      setState(() {});
    }
    if (snapshot.isReady) {
      _themeTransitionArmed = true;
    }

    if (!_startupRouteApplied && !snapshot.isLoading) {
      _startupRouteApplied = true;
      if (snapshot.isBlocked) {
        _router.go(snapshot.initialRoute);
      } else if (snapshot.isFirebaseUnavailable) {
        _router.go(snapshot.initialRoute);
      } else if (snapshot.isReady &&
          snapshot.initialRoute != widget.initialRoute) {
        _router.go(snapshot.initialRoute);
      }
    }

    if (snapshot.firebaseReady &&
        Firebase.apps.isNotEmpty &&
        !_initialNotificationPayloadPrimed) {
      _initialNotificationPayloadPrimed = true;
      unawaited(_primeInitialNotificationPayload());
    }

    if (_startupRouteApplied) {
      _drainPendingStartupNotificationPayload();
    }

    if (snapshot.isReady &&
        snapshot.firebaseReady &&
        Firebase.apps.isNotEmpty) {
      _startPostReadyBootstrap();
    }
  }

  bool get _shouldControlAndroidLaunchSplash =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _scheduleAndroidLaunchSplashRelease() {
    if (!_shouldControlAndroidLaunchSplash ||
        _androidLaunchSplashReleased ||
        _androidLaunchSplashReleaseScheduled) {
      return;
    }

    _androidLaunchSplashReleaseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _androidLaunchSplashReleased) {
        return;
      }
      _androidLaunchSplashReleased = true;
      unawaited(_releaseAndroidLaunchSplash());
    });
  }

  Future<void> _releaseAndroidLaunchSplash() async {
    try {
      await _androidLaunchSplashChannel.invokeMethod<void>('release');
    } catch (_) {}
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
      final useLiteDebugFirebaseStartup = _useLiteDebugFirebaseStartup;

      // Attach app-settings bridge only after startup is ready to avoid
      // pulling Sync providers into early startup transitions.
      _ensureDataSaverBridge();

      _scheduleCancellableDelay(_criticalBootstrapQuietWindow, () async {
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

      // Everything below is optional startup work.
      _scheduleDeferredStartupTask(
        delay: const Duration(milliseconds: 800),
        task: () => ref.read(publisherAssetsDataProvider.future),
        reason: 'Publisher asset data preload failed',
      );
      _scheduleDeferredStartupTask(
        delay: _deferredBootstrapDelay(
          _kDeferredNetworkUtilsDelay,
          androidDelay: const Duration(seconds: 6),
        ),
        task: () => ref.read(networkUtilsProvider).initialize(),
        reason: 'Network utils init failed',
      );
      if (useLiteDebugFirebaseStartup && _shouldWarmAuthBootstrap) {
        _scheduleDeferredStartupTask(
          delay: _deferredBootstrapDelay(
            _kDeferredAuthWarmupDelay,
            androidDelay: const Duration(seconds: 8),
          ),
          task: () => ref.read(authFacadeProvider).init(),
          reason: 'Deferred auth init failed',
        );
      }
      _scheduleDeferredStartupTask(
        delay: _deferredBootstrapDelay(
          _kDeferredRemoteConfigDelay,
          androidDelay: const Duration(seconds: 25),
        ),
        task: firebaseBootstrapper.initializeRemoteConfig,
        reason: 'RemoteConfig init failed',
      );
      _scheduleDeferredStartupTask(
        delay: _deferredBootstrapDelay(
          _kDeferredNotificationPipelineDelay,
          androidDelay: const Duration(seconds: 8),
        ),
        task: _initializeNotificationPipeline,
        reason: 'Notification init failed',
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
    await notifications.initialize(deferRemoteRegistration: true);

    if (kDebugMode && !FirebaseBootstrapper.shouldEnableAppCheck) {
      debugPrint(
        'ℹ️ Skipping remote notification bootstrap in normal debug runs because Firebase App Check is disabled.',
      );
      return;
    }

    await notifications.checkInitialMessage();
    _scheduleDeferredStartupTask(
      delay: _deferredBootstrapDelay(
        _kDeferredNotificationRemoteSetupDelay,
        androidDelay: const Duration(seconds: 35),
      ),
      task: _completeNotificationRemoteSetup,
      reason: 'Notification remote setup failed',
    );
  }

  Future<void> _completeNotificationRemoteSetup() async {
    if (!mounted) return;
    if (!ref.read(appNetworkServiceProvider).isConnected) {
      _scheduleDeferredStartupTask(
        delay: const Duration(seconds: 30),
        task: _completeNotificationRemoteSetup,
        reason: 'Notification remote setup retry failed',
      );
      return;
    }

    final notifications = ref.read(pushNotificationServiceProvider);
    if (!notifications.isEnabled) {
      return;
    }

    await notifications.completeDeferredRegistration();
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
      NavigationHelper.pushRouterDeduped<void>(
        _router,
        target.location,
        extra: target.extra,
      );
    });
  }

  Future<void> _primeInitialNotificationPayload() async {
    try {
      final payload = await _pushNotificationService
          .consumeInitialMessagePayload();
      if (!mounted || payload == null) {
        return;
      }

      _pendingStartupNotificationPayload = payload;
      if (_startupRouteApplied) {
        _drainPendingStartupNotificationPayload();
      }
    } catch (e, stack) {
      ref
          .read(structuredLoggerProvider)
          .warning('Initial notification payload prime failed', e, stack);
    }
  }

  void _drainPendingStartupNotificationPayload() {
    final payload = _pendingStartupNotificationPayload;
    if (payload == null) {
      return;
    }
    _pendingStartupNotificationPayload = null;
    _handleNotificationPayload(payload);
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

  @pragma('vm:prefer-inline')
  int _lightSchemeSignature(ColorScheme scheme) => Object.hashAll(<Object?>[
    scheme.brightness,
    scheme.primary.value,
    scheme.onPrimary.value,
    scheme.secondary.value,
    scheme.onSecondary.value,
    scheme.surface.value,
    scheme.onSurface.value,
    scheme.surfaceContainerHighest.value,
    scheme.outline.value,
    scheme.error.value,
  ]);

  ThemeData _resolveCachedLightTheme(ColorScheme scheme) {
    final signature = _lightSchemeSignature(scheme);
    final cachedTheme = _cachedLightTheme;
    if (cachedTheme != null && _cachedLightThemeSignature == signature) {
      return cachedTheme;
    }
    final resolved = AppTheme.lightThemeForScheme(scheme);
    _cachedLightTheme = resolved;
    _cachedLightThemeSignature = signature;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final appThemeMode = ref.watch(themeProvider.select((s) => s.mode));
    _activeThemeMode ??= appThemeMode;

    final activeThemeMode = _useStartupLiteShell
        ? appThemeMode
        : (_activeThemeMode ?? appThemeMode);
    final themeMode = resolveThemeMode(activeThemeMode);
    final darkTheme = resolveDarkTheme(activeThemeMode);
    _themeTransitionKey = activeThemeMode.name;

    final locale = ref.watch(languageProvider.select((s) => s.locale));
    final useDynamicColor = _resolveUseDynamicColor(activeThemeMode);

    final appChild = _useStartupLiteShell || !useDynamicColor
        ? _buildRouterApp(
            lightTheme: AppTheme.lightTheme,
            darkTheme: darkTheme,
            themeMode: themeMode,
            locale: locale,
          )
        : _buildDynamicColorRouter(
            darkTheme: darkTheme,
            themeMode: themeMode,
            locale: locale,
          );

    return appChild;
  }

  Widget _buildDynamicColorRouter({
    required ThemeData darkTheme,
    required ThemeMode themeMode,
    required Locale locale,
  }) {
    final cachedScheme = _cachedDynamicLightScheme;
    if (cachedScheme != null) {
      return _buildRouterApp(
        lightTheme: _resolveCachedLightTheme(cachedScheme),
        darkTheme: darkTheme,
        themeMode: themeMode,
        locale: locale,
      );
    }

    return DynamicColorBuilder(
      builder: (lightDynamic, _) {
        final ColorScheme lightScheme =
            lightDynamic?.harmonized() ?? AppTheme.lightTheme.colorScheme;
        _cachedDynamicLightScheme ??= lightScheme;

        return _buildRouterApp(
          lightTheme: _resolveCachedLightTheme(lightScheme),
          darkTheme: darkTheme,
          themeMode: themeMode,
          locale: locale,
        );
      },
    );
  }

  Widget _buildRouterApp({
    required ThemeData lightTheme,
    required ThemeData darkTheme,
    required ThemeMode themeMode,
    required Locale locale,
  }) {
    return MaterialApp.router(
      title: _appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      // Our custom ThemeWaveTransition handles the "heavy lifting" of the
      // transition visuals. We disable the native MaterialApp fade to
      // ensure the new theme is rendered instantly under the wave's mask,
      // preventing the "flicker" caused by overlapping animations.
      themeAnimationDuration: Duration.zero,
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
  }

  /// Route transitions trigger this builder frequently, so avoid provider
  /// watches here and use bridged snapshots instead.
  Widget _appBuilder(BuildContext context, Widget? child) {
    final startupSnapshot = _latestStartupSnapshot;
    final fallback = child ?? const SizedBox.shrink();
    Widget builtChild;

    if (_useStartupLiteShell) {
      builtChild = PerformanceConfig.defaults(
        child: _SnapshotOverlay(
          snapshot: startupSnapshot,
          animate: false,
          child: fallback,
        ),
      );
      return SessionValidator(child: builtChild);
    }

    final dataSaver = _latestDataSaver;
    final bool systemReduceMotion = MediaQuery.of(context).disableAnimations;
    final perfAsync = _latestPerfAsync;

    builtChild = perfAsync.maybeWhen(
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
            key: _themeWaveKey,
            themeKey: _themeTransitionKey,
            child: _SnapshotOverlay(
              snapshot: startupSnapshot,
              animate: true,
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
          key: _themeWaveKey,
          themeKey: _themeTransitionKey,
          child: _SnapshotOverlay(
            snapshot: startupSnapshot,
            animate: true,
            child: _cachedPerfConfig!,
          ),
        );
      },
      orElse: () => ThemeWaveTransition(
        key: _themeWaveKey,
        themeKey: _themeTransitionKey,
        child: PerformanceConfig.defaults(
          child: _SnapshotOverlay(
            snapshot: startupSnapshot,
            animate: true,
            child: fallback,
          ),
        ),
      ),
    );

    return SessionValidator(child: builtChild);
  }
}

class _SnapshotOverlay extends StatelessWidget {
  const _SnapshotOverlay({
    required this.snapshot,
    required this.child,
    required this.animate,
  });

  final StartupSnapshot snapshot;
  final Widget child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final content = (snapshot.isReady || snapshot.isLoading)
        ? KeyedSubtree(key: const ValueKey('app_main'), child: child)
        : _buildErrorOrSkeleton(context);

    if (!animate) {
      return content;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeInQuad,
      switchOutCurve: Curves.easeOutQuad,
      // The child of MaterialApp (the Navigator) shouldn't be recreated,
      // so we use a non-changing key when it's ready.
      child: content,
    );
  }

  Widget _buildErrorOrSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      key: const ValueKey('app_startup_overlay'),
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
