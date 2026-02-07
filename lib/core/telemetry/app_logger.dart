import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized logger for the application.
/// 
/// Channels logs to:
/// - **Console**: Beautifully formatted logs for development.
/// - **Crashlytics**: Non-fatal warnings and errors for production monitoring.
/// - **Analytics**: Key business metrics and performance events.
class AppLogger {

  AppLogger._();
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      printTime: true,
    ),
  );

  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log a debug message (Development only).
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message (General flow).
  static void info(String message) {
    _logger.i(message);
    if (!kDebugMode) {
      _crashlytics.log('INFO: $message');
    }
  }

  /// Log a warning (Something unexpected but recoverable).
  static void warn(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    if (!kDebugMode) {
      _crashlytics.recordError(error ?? Exception(message), stackTrace,
          reason: 'WARN: $message');
    }
  }

  /// Log an error (Something failed).
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    if (!kDebugMode) {
      _crashlytics.recordError(error ?? Exception(message), stackTrace,
          reason: 'ERROR: $message');
    }
  }

  /// Log a performance metric.
  static void metric(String name, int valueMilliseconds) {
    _logger.t('⏱ Metric: $name = ${valueMilliseconds}ms');
    if (!kDebugMode) {
      _analytics.logEvent(
        name: 'performance_metric',
        parameters: {
          'metric_name': name,
          'duration_ms': valueMilliseconds,
        },
      );
    }
  }
}