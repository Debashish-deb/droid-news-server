import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../../infrastructure/services/notifications/push_notification_service.dart';
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

  /// Centralized synchronized initialization
  static Future<void> autoInitialize() async {
    await _lock.synchronized(() async {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
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
      PushNotificationService.registerBackgroundHandler();
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

  Future<void> initializeAppCheckService() async {
    final debugFlag = _kEnableDebugAppCheck.trim().toLowerCase();
    final debugAppCheckEnabled =
        debugFlag.isEmpty || debugFlag == '1' || debugFlag == 'true';
    if (kDebugMode && !debugAppCheckEnabled) {
      debugPrint(
        'ℹ️ Firebase App Check skipped in debug (--dart-define=ENABLE_DEBUG_APP_CHECK=false).',
      );
      return;
    }

    try {
      await FirebaseAppCheck.instance
          .activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
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

    await remoteConfig.fetchAndActivate();
  }
}
