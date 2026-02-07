// lib/core/resilience/resilience_service.dart

import 'dart:async';

enum CircuitState { closed, open, halfOpen }

/// Service to handle service resilience using the Circuit Breaker pattern.
class ResilienceService {
  final Map<String, _CircuitBreaker> _circuits = {};

  /// Executes an async action with circuit breaker protection.
  Future<T> execute<T>({
    required String serviceName,
    required Future<T> Function() action,
    T Function()? fallback,
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(seconds: 30),
  }) async {
    final breaker = _circuits.putIfAbsent(
      serviceName,
      () => _CircuitBreaker(
        threshold: failureThreshold,
        resetTimeout: resetTimeout,
      ),
    );

    return breaker.execute(action, fallback: fallback);
  }

  /// Get status of all circuits for monitoring
  Map<String, CircuitState> getCircuitStatuses() {
    return _circuits.map((key, value) => MapEntry(key, value.state));
  }
}

class _CircuitBreaker {

  _CircuitBreaker({required this.threshold, required this.resetTimeout});
  final int threshold;
  final Duration resetTimeout;

  int _failures = 0;
  CircuitState _state = CircuitState.closed;
  DateTime? _lastFailureTime;

  CircuitState get state {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      if (DateTime.now().difference(_lastFailureTime!) > resetTimeout) {
        return CircuitState.halfOpen;
      }
    }
    return _state;
  }

  Future<T> execute<T>(Future<T> Function() action, {T Function()? fallback}) async {
    final currentState = state;

    if (currentState == CircuitState.open) {
      if (fallback != null) return fallback();
      throw Exception('Circuit is open for this service');
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      if (fallback != null) return fallback();
      rethrow;
    }
  }

  void _onSuccess() {
    _failures = 0;
    _state = CircuitState.closed;
  }

  void _onFailure() {
    _failures++;
    _lastFailureTime = DateTime.now();
    if (_failures >= threshold) {
      _state = CircuitState.open;
    }
  }
}
