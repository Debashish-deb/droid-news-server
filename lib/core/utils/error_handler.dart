  import 'package:flutter/foundation.dart' show debugPrint;

import '../telemetry/observability_service.dart' show ObservabilityService;
  
  ObservabilityService? _obs;

  void setObservabilityService(ObservabilityService service) {
    _obs = service;
  }

  Future<void> initialize() async {}

  /// Log non-fatal errors
  void logError(Object error, StackTrace? stackTrace, {String? reason}) {
    final obs = _obs;
    if (obs != null) {
      obs.recordError(error, stackTrace, reason: reason);
    } else {
      // Fallback to debug print if service not available
      debugPrint('❌ ERROR: $reason\n$error\n$stackTrace');
    }
  }

  /// Log custom information for debugging
  void log(String message) {
    final obs = _obs;
    if (obs != null) {
      obs.logEvent('info_log', parameters: {'message': message});
    } else {
      debugPrint('ℹ️ $message');
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    final obs = _obs;
    if (obs != null) {
      await obs.setUserId(userId);
    }
  }

  /// Set custom key-value pairs for debugging
  Future<void> setCustomKey(String key, dynamic value) async {
    final obs = _obs;
    if (obs != null) {
      obs.logEvent('custom_key', parameters: {'key': key, 'value': value.toString()});
    }
  }

