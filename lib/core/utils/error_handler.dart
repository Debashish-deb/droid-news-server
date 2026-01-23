import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Global error handler for production apps
class ErrorHandler {
  static Future<void> initialize() async {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };

    // Catch Dart errors outside Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };
  }

  /// Log non-fatal errors
  static void logError(Object error, StackTrace? stackTrace, {String? reason}) {
    if (kDebugMode) {
      print('Error${reason != null ? " ($reason)" : ""}: $error');
      if (stackTrace != null) print(stackTrace);
    }

    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
      );
    }
  }

  /// Log custom information for debugging
  static void log(String message) {
    if (kDebugMode) {
      print('INFO: $message');
    }

    if (kReleaseMode) {
      FirebaseCrashlytics.instance.log(message);
    }
  }

  /// Set user identifier for crash reports
  static Future<void> setUserId(String userId) async {
    if (kReleaseMode) {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    }
  }

  /// Set custom key-value pairs for debugging
  static Future<void> setCustomKey(String key, dynamic value) async {
    if (kReleaseMode) {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    }
  }
}
