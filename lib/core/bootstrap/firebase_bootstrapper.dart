import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart' as synchronized;
import '../../tools/firebase_options.dart';
import 'bootstrap_task.dart';

class FirebaseBootstrapper implements BootstrapTask {
  @override
  String get name => 'Firebase';

  static final _lock = synchronized.Lock();
  static const String _kEnableDebugAppCheck = String.fromEnvironment(
    'ENABLE_DEBUG_APP_CHECK',
  );
  static const String _kForceDebugAppCheckProvider = String.fromEnvironment(
    'FORCE_DEBUG_APP_CHECK_PROVIDER',
  );

  static bool get _debugAppCheckEnabled {
    final debugFlag = _kEnableDebugAppCheck.trim().toLowerCase();
    return debugFlag == '1' || debugFlag == 'true';
  }

  static bool get _forceDebugAppCheckProvider {
    final forceFlag = _kForceDebugAppCheckProvider.trim().toLowerCase();
    return forceFlag == '1' || forceFlag == 'true';
  }

  static bool get shouldEnableAppCheck => kReleaseMode || _debugAppCheckEnabled;

  /// Centralized synchronized initialization
  static Future<void> autoInitialize() async {
    await _lock.synchronized(() async {
      if (Firebase.apps.isEmpty) {
        try {
          await DefaultFirebaseOptions.initializeApp();
          debugPrint('✅ Firebase synchronized initialization successful');
        } on FirebaseException catch (e) {
          if (e.code == 'duplicate-app') {
            debugPrint(
              'ℹ️ Firebase already initialized (Caught duplicate-app)',
            );
          } else {
            rethrow;
          }
        }
      } else {
        debugPrint('ℹ️ Firebase already initialized (Checked via Lock)');
      }
    });
  }

  @override
  Future<void> initialize({
    bool fetchRemoteConfig = true,
    bool initializeAppCheck = true,
  }) async {
    // Check if Firebase is already initialized (important for hot restart)
    try {
      await autoInitialize();
    } on FirebaseException catch (e) {
      // Handle duplicate-app error that can occur during hot restart
      if (e.code != 'duplicate-app') {
        rethrow;
      }
      // If it's a duplicate-app error, continue - Firebase is already initialized
    }

    if (kDebugMode && !shouldEnableAppCheck) {
      await disableAppCheckAutoRefreshInDebug();
    }

    if (initializeAppCheck) {
      await initializeAppCheckService();
    }

    // Set up crash reporting in production
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    if (fetchRemoteConfig) {
      await initializeRemoteConfig();
    }
  }

  Future<void> _installDebugAppCheckProviderForHotRestart() async {
    if (shouldEnableAppCheck || !_forceDebugAppCheckProvider) {
      return;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
      debugPrint(
        'ℹ️ Firebase App Check debug provider installed for hot restart stability.',
      );
    } catch (e) {
      debugPrint(
        '⚠️ Failed to install Firebase App Check debug provider in debug: $e',
      );
    }
  }

  Future<void> disableAppCheckAutoRefreshInDebug() async {
    if (shouldEnableAppCheck) {
      return;
    }

    try {
      await _installDebugAppCheckProviderForHotRestart();
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(false);
      debugPrint(
        _forceDebugAppCheckProvider
            ? 'ℹ️ Firebase App Check auto-refresh disabled; debug provider forced for hot restart stability.'
            : 'ℹ️ Firebase App Check fully disabled for normal debug runs.',
      );
    } catch (e) {
      debugPrint(
        '⚠️ Failed to disable Firebase App Check auto-refresh in debug: $e',
      );
    }
  }

  Future<void> initializeAppCheckService() async {
    if (!shouldEnableAppCheck) {
      if (kDebugMode) {
        await disableAppCheckAutoRefreshInDebug();
        debugPrint(
          _forceDebugAppCheckProvider
              ? 'ℹ️ Firebase App Check debug provider forced for this debug run. Enable full App Check with --dart-define=ENABLE_DEBUG_APP_CHECK=true.'
              : 'ℹ️ Firebase App Check is off in normal debug runs. Enable with --dart-define=ENABLE_DEBUG_APP_CHECK=true. Use --dart-define=FORCE_DEBUG_APP_CHECK_PROVIDER=true only if you specifically need the hot-restart workaround.',
        );
      } else {
        debugPrint(
          'ℹ️ Firebase App Check is disabled in profile builds. Release builds use Play Integrity by default.',
        );
      }
      return;
    }

    try {
      await FirebaseAppCheck.instance
          .activate(
            androidProvider: kReleaseMode
                ? AndroidProvider.playIntegrity
                : AndroidProvider.debug,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⚠️ Firebase App Check activation timed out');
            },
          );
      debugPrint('🛡️ Firebase App Check initialized');
    } catch (e) {
      debugPrint('⚠️ Firebase App Check initialization failed: $e');
    }
  }

  Future<void> initializeRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setDefaults({
      'min_trust_level': 2,
      'app_version_required': '1.0.0',
      'maintenance_mode': false,
    });
    unawaited(_fetchAndActivateWithRetry(remoteConfig));
  }

  Future<void> _fetchAndActivateWithRetry(
    FirebaseRemoteConfig remoteConfig,
  ) async {
    const backoffs = <Duration>[
      Duration.zero,
      Duration(seconds: 20),
      Duration(seconds: 60),
    ];

    for (var attempt = 0; attempt < backoffs.length; attempt++) {
      final delay = backoffs[attempt];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      try {
        await remoteConfig.fetchAndActivate().timeout(
          const Duration(seconds: 10),
          onTimeout: () => false,
        );
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Remote Config fetch attempt ${attempt + 1} failed: $e',
          );
        }
      }
    }
  }
}
