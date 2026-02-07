
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

enum MetricType {
  counter,
  gauge,
  histogram
}

class TelemetryMetric {

  const TelemetryMetric(this.name, this.value, {this.type = MetricType.counter, this.tags = const {}});
  final String name;
  final MetricType type;
  final double value;
  final Map<String, dynamic> tags;
}

class ObservabilityControlPlane {

  ObservabilityControlPlane({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
    FirebasePerformance? performance,
  })  : _analytics = analytics ?? FirebaseAnalytics.instance,
        _crashlytics = crashlytics ?? FirebaseCrashlytics.instance,
        _performance = performance ?? FirebasePerformance.instance;
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;
  final FirebasePerformance _performance;

  final Map<String, Trace> _activeTraces = {};

  // 4. Trace Management
  Future<void> startTrace(String name) async {
    final trace = _performance.newTrace(name);
    await trace.start();
    _activeTraces[name] = trace;
    debugPrint('⏱️ TRACE START: $name');
  }

  Future<void> stopTrace(String name) async {
    final trace = _activeTraces.remove(name);
    if (trace != null) {
      await trace.stop();
      debugPrint('⏱️ TRACE STOP: $name');
    }
  }

  // 1. Business Metrics (High-level)
  Future<void> logBusinessEvent(String eventName, Map<String, dynamic> params) async {
    // Analytics expects Map<String, Object>, so we cast/copy.
    // Filtering nulls to be safe if the SDK implies non-nullable Object.
    final safeParams = Map<String, Object>.from(
      params..removeWhere((key, value) => value == null)
    );
    await _analytics.logEvent(name: eventName, parameters: safeParams);
    debugPrint('📊 BIZ EVENT: $eventName $params');
  }

  // 2. Performance Tracing
  Future<void> recordMetric(TelemetryMetric metric) async {
    // In strict enterprise, we'd send this to Datadog/Prometheus wrapper.
    // For now, mapping to Analytics Custom Event
    final safeParams = <String, Object>{
      'value': metric.value,
    };
    metric.tags.forEach((key, value) {
      if (value != null) {
        safeParams[key] = value;
      }
    });

    await _analytics.logEvent(name: 'metric_${metric.name}', parameters: safeParams);
  }

  // 3. System Health (Error Tracing)
  Future<void> recordError(dynamic exception, StackTrace? stack, {bool fatal = false}) async {
    await _crashlytics.recordError(exception, stack, fatal: fatal);
    debugPrint('💥 SYSTEM ERROR: $exception');
  }
  
  // 4. Trace Context
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
    await _crashlytics.setUserIdentifier(userId);
  }
}
