import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../infrastructure/observability/analytics_service.dart'
    show AnalyticsService;
import '../architecture/failure.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Global error handler for the app
class ErrorHandler {
  ErrorHandler._();

  /// Log non-fatal errors (For backward compatibility)
  static void logError(Object error, StackTrace? stackTrace, {String? reason}) {
    final String rawMessage = error.toString();
    final String sanitizedMessage = _sanitizeError(rawMessage);

    AnalyticsService.logError(
      error: sanitizedMessage,
      location: stackTrace?.toString().split('\n').first ?? 'unknown',
    );

    if (!kDebugMode) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: reason,
        );
      } catch (e) {
        debugPrint('Failed to report to Crashlytics: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('❌ Error ($reason): $sanitizedMessage');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
    }
  }

  /// Convert exception to AppFailure
  static AppFailure handleException(dynamic error, [StackTrace? stackTrace]) {
    logError(error, stackTrace, reason: 'unhandled_exception');

    if (!kDebugMode) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stackTrace);
      } catch (e) {
        debugPrint('Failed to report to Crashlytics: $e');
      }
    }

    // No extra debug prints here as logError handles it
    if (error is AppFailure) {
      return error;
    }

    if (error is SocketException) {
      return NetworkFailure(error.message, stackTrace);
    }

    if (error is TimeoutException) {
      return TimeoutFailure(error.message ?? 'Request timed out.', stackTrace);
    }

    if (error is HttpException) {
      return ServerFailure('HTTP Error: ${error.message}', null, stackTrace);
    }

    if (error is FormatException) {
      return ParseFailure(error.message, stackTrace);
    }

    return UnknownFailure(error.toString(), stackTrace);
  }

  /// Sanitize error messages to remove sensitive info (PII)
  static String _sanitizeError(String message) {
    // Basic PII removal (emails, potential tokens)
    return message
        .replaceAll(
          RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
          '[EMAIL]',
        )
        .replaceAll(RegExp(r'Token [a-zA-Z0-9\-_.]+'), 'Token [REDACTED]')
        .replaceAll(RegExp(r'password=[^&\s]+'), 'password=[REDACTED]')
        .replaceAll(RegExp(r'secret=[^&\s]+'), 'secret=[REDACTED]');
  }

  /// Show error in UI (for widgets to use)
  static void showError(
    dynamic error,
    void Function(AppFailure) displayCallback,
  ) {
    final appFailure = handleException(error);
    displayCallback(appFailure);
  }
}
