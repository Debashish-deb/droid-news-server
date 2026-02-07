import 'dart:async';
import 'package:flutter/foundation.dart';
import 'tts_analytics.dart';

enum CircuitState { closed, open, halfOpen }

class SynthesisCircuitBreaker {
  SynthesisCircuitBreaker({required this.analytics});

  final TtsAnalytics analytics;


  static const int _failureThreshold = 5;
  static const Duration _resetTimeout = Duration(minutes: 5);


  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _openTime;

  bool get isOpen => _state == CircuitState.open;

  Future<T> execute<T>(Future<T> Function() action) async {
    if (_state == CircuitState.open) {
      if (_shouldAttemptReset()) {
        _transitionToHalfOpen();
      } else {
        throw Exception('CircuitBreaker is OPEN');
      }
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure(e);
      rethrow;
    }
  }

  bool _shouldAttemptReset() {
    if (_openTime == null) return false;
    return DateTime.now().difference(_openTime!) > _resetTimeout;
  }

  void _transitionToHalfOpen() {
    _state = CircuitState.halfOpen;
    debugPrint('🔌 TTS Circuit Breaker: Half-Open (Probing backend...)');
  }

  void _onSuccess() {
    if (_state != CircuitState.closed) {
      _state = CircuitState.closed;
      _failureCount = 0;
      _openTime = null;
      debugPrint('🔌 TTS Circuit Breaker: Check Succeeded. Circuit CLOSED (Recovered).');
    }
  }

  void _onFailure(Object error) {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      _openTime = DateTime.now();
      debugPrint('🔌 TTS Circuit Breaker: Probe Failed. Circuit Re-OPENED.');
    } else if (_failureCount >= _failureThreshold) {
      _state = CircuitState.open;
      _openTime = DateTime.now();
      debugPrint('🔌 TTS Circuit Breaker: Threshold Reached. Circuit OPENED.');
      analytics.trackSynthesisError('CircuitBreaker OPENED', Duration.zero);
    }
  }
  
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _openTime = null;
  }
}
