/// Interface for distributed tracing service
abstract class TracingService {
  /// Start a new trace span
  Future<void> startSpan(String name, {Map<String, dynamic>? attributes});

  /// End the current span
  Future<void> endSpan(String name, {Map<String, dynamic>? attributes});

  /// Add an event/log to the current span
  void addEvent(String name, {Map<String, dynamic>? attributes});

  /// Record an error in the current span
  void recordError(dynamic error, StackTrace? stackTrace, {String? reason});
}

/// No-op implementation for when tracing is disabled or initializing
class NoOpTracingService implements TracingService {
  @override
  Future<void> startSpan(String name, {Map<String, dynamic>? attributes}) async {}

  @override
  Future<void> endSpan(String name, {Map<String, dynamic>? attributes}) async {}

  @override
  void addEvent(String name, {Map<String, dynamic>? attributes}) {}

  @override
  void recordError(dynamic error, StackTrace? stackTrace, {String? reason}) {}
}
