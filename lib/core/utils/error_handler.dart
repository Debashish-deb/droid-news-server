import 'package:flutter/foundation.dart';
import '../../bootstrap/di/injection_container.dart' show sl;
import '../telemetry/observability_service.dart';

/// Global error handler for production apps
/// Delegates to unified ObservabilityService
class ErrorHandler {
  static ObservabilityService? get _obs {
    try {
      if (sl.isRegistered<ObservabilityService>()) {
        return sl<ObservabilityService>();
      }
    } catch (e) {
      debugPrint('⚠️ ObservabilityService not available: $e');
    }
    return null;
  }

  static Future<void> initialize() async {}

  /// Log non-fatal errors
  static void logError(Object error, StackTrace? stackTrace, {String? reason}) {
    final obs = _obs;
    if (obs != null) {
      obs.recordError(error, stackTrace, reason: reason);
    } else {
      // Fallback to debug print if service not available
      debugPrint('❌ ERROR: $reason\n$error\n$stackTrace');
    }
  }

  /// Log custom information for debugging
  static void log(String message) {
    final obs = _obs;
    if (obs != null) {
      obs.logEvent('info_log', parameters: {'message': message});
    } else {
      debugPrint('ℹ️ $message');
    }
  }

  /// Set user identifier for crash reports
  static Future<void> setUserId(String userId) async {
    final obs = _obs;
    if (obs != null) {
      await obs.setUserId(userId);
    }
  }

  /// Set custom key-value pairs for debugging
  static Future<void> setCustomKey(String key, dynamic value) async {
    final obs = _obs;
    if (obs != null) {
      obs.logEvent('custom_key', parameters: {'key': key, 'value': value.toString()});
    }
  }
}
