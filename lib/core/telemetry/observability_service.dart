import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'structured_logger.dart';
import 'performance_metrics.dart';

/// Unified service for all observability concerns.
/// Manually registered in DI to ensure availability before any error handlers.
class ObservabilityService {

  ObservabilityService()
      : _analytics = Firebase.apps.isNotEmpty ? FirebaseAnalytics.instance : null,
        _crashlytics = Firebase.apps.isNotEmpty ? FirebaseCrashlytics.instance : null;
  final FirebaseAnalytics? _analytics;
  final FirebaseCrashlytics? _crashlytics;
  final StructuredLogger _logger = StructuredLogger();
  final PerformanceMetrics _metrics = PerformanceMetrics();

  /// Logs an event to Analytics and Structured Logs.
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    _logger.info('Event: $name', parameters);
    if (_analytics != null) {
      await _analytics.logEvent(name: name, parameters: parameters);
    }
  }

  /// Records a non-fatal error.
  Future<void> recordError(dynamic error, StackTrace? stack, {String? reason}) async {
    _logger.error('Error: $reason', error, stack);
    if (_crashlytics != null) {
      await _crashlytics.recordError(error, stack, reason: reason);
    }
  }

  /// Records a fatal error (crash).
  Future<void> recordFatalError(dynamic error, StackTrace? stack) async {
    _logger.error('FATAL ERROR: $error', error, stack);
    if (_crashlytics != null) {
      await _crashlytics.recordError(error, stack, fatal: true);
    }
  }

  /// Sets user identity for sessions.
  Future<void> setUserId(String userId) async {
    if (_analytics != null) {
      await _analytics.setUserId(id: userId);
    }
    if (_crashlytics != null) {
      await _crashlytics.setUserIdentifier(userId);
    }
  }

  /// Measures a specific operation's performance.
  Future<T> measure<T>(String traceName, Future<T> Function() action) async {
    _metrics.startTimer(traceName);
    try {
      final result = await action();
      _metrics.stopTimer(traceName, attributes: {'status': 'success'});
      return result;
    } catch (e) {
      _metrics.stopTimer(traceName, attributes: {'status': 'error'});
      rethrow;
    }
  }
}
