import 'dart:math';

/// Handles exponential backoff for sync operations.
class RetryEngine {
  int _attempt = 0;
  static const int _maxAttempts = 10;
  
  /// Base delay in seconds.
  static const int _baseDelay = 2;

  /// Resets the retry counter on success.
  void reset() {
    _attempt = 0;
  }

  /// Calculates the next delay duration.
  /// 
  /// Formula: base * 2^(attempt) + jitter
  Duration getNextDelay() {
    if (_attempt >= _maxAttempts) {
    
      return const Duration(hours: 24);
    }

    final exponential = _baseDelay * pow(2, _attempt);
    _attempt++;


    final jitter = Random().nextInt(1000); 
    final milliseconds = (exponential * 1000).toInt() + jitter;

    return Duration(milliseconds: milliseconds);
  }

  /// Should we keep retrying?
  bool get canRetry => _attempt < _maxAttempts;
}
