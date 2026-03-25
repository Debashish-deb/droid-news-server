import 'dart:async' show unawaited;
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/app_paths.dart';
import '../security/security_service.dart';
import '../services/splash_service.dart';
import 'firebase_bootstrapper.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum StartupState { loading, ready, firebaseUnavailable, blocked }

class StartupSnapshot {
  const StartupSnapshot({
    required this.state,
    required this.initialRoute,
    this.message,
    this.firebaseReady = false,
  });

  const StartupSnapshot.loading()
    : this(
        state: StartupState.loading,
        initialRoute: AppPaths.splash,
        firebaseReady: false,
      );

  const StartupSnapshot.ready({required String initialRoute})
    : this(
        state: StartupState.ready,
        initialRoute: initialRoute,
        firebaseReady: true,
      );

  const StartupSnapshot.firebaseUnavailable({String? message})
    : this(
        state: StartupState.firebaseUnavailable,
        initialRoute: AppPaths.splash,
        message: message,
        firebaseReady: false,
      );

  const StartupSnapshot.blocked({String? message})
    : this(
        state: StartupState.blocked,
        initialRoute: AppPaths.securityLockout,
        message: message,
        firebaseReady: false,
      );

  final StartupState state;
  final String initialRoute;
  final String? message;
  final bool firebaseReady;

  bool get isLoading => state == StartupState.loading;
  bool get isReady => state == StartupState.ready;
  bool get isFirebaseUnavailable => state == StartupState.firebaseUnavailable;
  bool get isBlocked => state == StartupState.blocked;
}

class StartupBootstrapRunner {
  StartupBootstrapRunner({
    required SharedPreferences prefs,
    required SecurityService securityService,
    required GoogleSignIn googleSignIn,
    this.firebaseTimeout = const Duration(milliseconds: 10000),
    this.sslTimeout = const Duration(milliseconds: 5000),
  }) : _prefs = prefs,
       _securityService = securityService,
       _googleSignIn = googleSignIn;

  final SharedPreferences _prefs;
  final SecurityService _securityService;
  final GoogleSignIn _googleSignIn;
  final Duration firebaseTimeout;
  final Duration sslTimeout;

  Future<StartupSnapshot> bootstrap() async {
    // Do not let Google account pre-warm block first route resolution.
    unawaited(
      _googleSignIn
          .signInSilently()
          .timeout(const Duration(seconds: 10))
          .catchError((e) {
            debugPrint('⚠️ Google pre-warm failed: $e');
            return null;
          }),
    );

    Object? firebaseError;
    var firebaseReady = Firebase.apps.isNotEmpty;

    if (!firebaseReady) {
      try {
        // Keep this lightweight to avoid duplicate bootstrap side-effects
        // (App Check / extra plugin work) in startup runner.
        await FirebaseBootstrapper.autoInitialize().timeout(firebaseTimeout);
      } catch (e) {
        firebaseError = e;
        debugPrint('⚠️ Firebase secondary error: $e');
      }
      firebaseReady = Firebase.apps.isNotEmpty;
    }

    if (kReleaseMode && !_securityService.isDeviceSecure) {
      final reason = _securityService.isRooted
          ? 'Root detected'
          : 'Insecure device/emulator';
      return StartupSnapshot.blocked(
        message:
            'Security requirements not met: $reason. Access denied in production.',
      );
    }

    String resolvedRoute = AppPaths.home;
    try {
      resolvedRoute = await SplashService(prefs: _prefs).resolveInitialRoute();
    } catch (error) {
      debugPrint('⚠️ Startup route resolution failed: $error');
    }

    if (!firebaseReady) {
      return StartupSnapshot.firebaseUnavailable(
        message: firebaseError?.toString(),
      ).copyWith(initialRoute: resolvedRoute);
    }

    return StartupSnapshot.ready(initialRoute: resolvedRoute);
  }
}

extension on StartupSnapshot {
  StartupSnapshot copyWith({String? initialRoute}) {
    return StartupSnapshot(
      state: state,
      initialRoute: initialRoute ?? this.initialRoute,
      message: message,
      firebaseReady: firebaseReady,
    );
  }
}

class StartupController extends StateNotifier<StartupSnapshot> {
  StartupController({
    StartupSnapshot initial = const StartupSnapshot.loading(),
    StartupBootstrapRunner? runner,
  }) : _runner = runner,
       super(initial);

  final StartupBootstrapRunner? _runner;

  Future<void> retry() async {
    if (_runner == null) {
      return;
    }
    state = const StartupSnapshot.loading();
    state = await _runner.bootstrap();
  }

  void setSnapshot(StartupSnapshot snapshot) {
    state = snapshot;
  }
}
