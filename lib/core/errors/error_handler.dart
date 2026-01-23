import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../architecture/failure.dart';
import '../analytics_service.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Global error handler for the app
class ErrorHandler {
  ErrorHandler._();

  /// Convert exception to AppFailure
  static AppFailure handleException(dynamic error, [StackTrace? stackTrace]) {
    // Log to analytics
    final String errorMessage = error.toString();
    AnalyticsService.logError(
      error: errorMessage,
      location: stackTrace?.toString().split('\n').first ?? 'unknown',
    );

    // Report to Crashlytics
    if (!kDebugMode) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stackTrace);
      } catch (e) {
        debugPrint('Failed to report to Crashlytics: $e');
      }
    }

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('❌ Error: $error');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
    }

    // Convert to AppFailure
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

  /// Handle error and return user-friendly AppFailure
  static AppFailure handle(dynamic error, [StackTrace? stackTrace]) {
    return handleException(error, stackTrace);
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
