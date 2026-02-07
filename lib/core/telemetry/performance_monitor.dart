import 'app_logger.dart';

/// Utility to measure code execution time.
class PerformanceMonitor {

  PerformanceMonitor(this._name) : _stopwatch = Stopwatch()..start();
  final String _name;
  final Stopwatch _stopwatch;

  /// Starts a new trace.
  static PerformanceMonitor start(String name) {
    return PerformanceMonitor(name);
  }

  /// Stops the trace and logs the duration via [AppLogger].
  void stop() {
    _stopwatch.stop();
    AppLogger.metric(_name, _stopwatch.elapsedMilliseconds);
  }
}

/// Helper extension to time async functions easily.
extension PerformanceExtension<T> on Future<T> {
  Future<T> measure(String name) async {
    final monitor = PerformanceMonitor.start(name);
    try {
      return await this;
    } finally {
      monitor.stop();
    }
  }
}
