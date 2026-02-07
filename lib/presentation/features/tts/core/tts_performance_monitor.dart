import 'package:flutter/foundation.dart';
import 'tts_analytics.dart';

class TtsPerformanceMonitor {
  TtsPerformanceMonitor({required this.analytics});

  final TtsAnalytics analytics;
  final List<Duration> _latencies = [];
  static const int _windowSize = 10;
  static const Duration _warningThreshold = Duration(seconds: 3);

  void recordLatency(Duration latency) {
    _latencies.add(latency);
    if (_latencies.length > _windowSize) {
      _latencies.removeAt(0);
    }

    _checkPerformance();
  }

  void _checkPerformance() {
    if (_latencies.isEmpty) return;

    final totalMs = _latencies.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    final averageMs = totalMs / _latencies.length;

    if (averageMs > _warningThreshold.inMilliseconds) {
      if (kDebugMode) {
        debugPrint('⚠️ TTS Performance Degradation: Avg Latency ${averageMs.toStringAsFixed(0)}ms');
      }
      analytics.trackPerformance('high_latency', Duration(milliseconds: averageMs.toInt()));
    }
  }
}
