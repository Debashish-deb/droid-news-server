import 'package:flutter/foundation.dart';

/// Service to track Key Performance Indicators (KPIs)
class PerformanceMetrics {
  factory PerformanceMetrics() => _instance;
  PerformanceMetrics._();
  static final PerformanceMetrics _instance = PerformanceMetrics._();

  final Map<String, int> _starts = {};

  /// Start measuring a metric
  void startTimer(String metricName) {
    _starts[metricName] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Stop measuring and log the duration
  void stopTimer(String metricName, {Map<String, dynamic>? attributes}) {
    if (!_starts.containsKey(metricName)) return;

    final start = _starts[metricName]!;
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    _starts.remove(metricName);

    _logMetric(metricName, duration, attributes);
  }

  void _logMetric(String name, int durationMs, Map<String, dynamic>? attributes) {
    if (kDebugMode) {
      debugPrint('⚡ Metric [$name]: ${durationMs}ms ${(attributes ?? "")}');
    }
  }
}
