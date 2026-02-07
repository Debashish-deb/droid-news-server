import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import 'bootstrap_task.dart';

class FirebaseBootstrapper implements BootstrapTask {
  @override
  String get name => 'Firebase';

  @override
  Future<void> initialize({bool fetchRemoteConfig = true}) async {
    // Check if Firebase is already initialized (important for hot restart)
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } on FirebaseException catch (e) {
      // Handle duplicate-app error that can occur during hot restart
      if (e.code != 'duplicate-app') {
        rethrow;
      }
      // If it's a duplicate-app error, continue - Firebase is already initialized
    }
    
    // Set up crash reporting in production
    if (!kDebugMode) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    if (fetchRemoteConfig) {
      await initializeRemoteConfig();
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
