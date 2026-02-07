import 'package:flutter/foundation.dart';
import '../../../../core/telemetry/observability_service.dart';

class TtsAnalytics {
  final ObservabilityService _observability = ObservabilityService();

  Future<void> trackPlaybackStart(String articleId) async {
    if (kDebugMode) {
      debugPrint('📊 TtsAnalytics: Playback started for $articleId');
    }
    await _observability.logEvent('tts_playback_start', parameters: {'article_id': articleId});
  }

  Future<void> trackSynthesisError(String error, Duration duration) async {
    if (kDebugMode) {
      debugPrint('📊❌ TtsAnalytics: Synthesis Error ($duration): $error');
    }
    await _observability.recordError(
      Exception(error), 
      StackTrace.current,
      reason: 'TTS Synthesis Failure (${duration.inMilliseconds}ms)',
    );
  }

  Future<void> trackCacheHit(bool hit) async {
    if (kDebugMode) {
      debugPrint('📊 TtsAnalytics: Cache ${hit ? "HIT" : "MISS"}');
    }
    await _observability.logEvent('tts_cache_status', parameters: {'hit': hit ? 1 : 0});
  }

  Future<void> trackPerformance(String operation, Duration duration) async {
    if (duration.inSeconds > 2) {
      if (kDebugMode) {
        debugPrint('📊⚠️ TtsAnalytics: Slow operation $operation took ${duration.inMilliseconds}ms');
      }
      await _observability.logEvent('tts_slow_op', parameters: {
        'operation': operation,
        'duration_ms': duration.inMilliseconds
      });
    }
  }
}
