/// Protects the system from repeated failures by "opening" the circuit.
class CircuitBreaker {
  bool _isOpen = false;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  
  static const int _threshold = 5;
  static const Duration _resetTimeout = Duration(minutes: 5);

  bool get canRequest {
    if (!_isOpen) return true;

    if (_lastFailureTime != null && 
        DateTime.now().difference(_lastFailureTime!) > _resetTimeout) {
      _isOpen = false; 
      _failureCount = 0;
      return true;
    }

    return false;
  }

  void onSuccess() {
    _failureCount = 0;
    _isOpen = false;
  }

  void onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= _threshold) {
      _isOpen = true;
    }
  }
}
