import 'dart:async';
import '../collection/ai_event_collector.dart';

/// Transforms raw event signals into high-level features for the AI model.
/// 
/// output: Stream of [AIFeatureVector]
class FeatureEngineeringService {

  FeatureEngineeringService(this._collector) {
    _collector.eventStream.listen(_processEvent);
  }
  final AIEventCollector _collector;
  
  int _sessionDepth = 0;
  final Map<String, int> _topicCounts = {};
  final DateTime _sessionStartTime = DateTime.now();

  final StreamController<Map<String, dynamic>> _featureStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get featureStream => _featureStream.stream;

  void _processEvent(Map<String, dynamic> event) {
    final action = event['action'];
    
    if (action == 'article_open') {
      _sessionDepth++;
    }

    if (action == 'read_duration') {
      final duration = event['duration'] as int;
      final engagementLevel = _calculateEngagement(duration);
      _emitFeature('engagement_score', engagementLevel);
    }

    if (action == 'scroll_velocity') {
      final velocity = event['velocity'] as double;
      _emitFeature('scroll_velocity', velocity);
    }

    if (action == 'interaction') {
      final type = event['type'];
      _emitFeature('interaction_$type', 1.0);
    }
    
    if (event.containsKey('topic') && event['topic'] != null) {
      final topic = event['topic'] as String;
      _topicCounts[topic] = (_topicCounts[topic] ?? 0) + 1;
      
      // ✅ FIX: Emit topic weights as features
      _emitFeature('topic_weight_$topic', _topicCounts[topic]);
    }

    _emitFeature('session_depth', _sessionDepth);
    
    // ✅ NEW: Session duration feature
    final sessionDuration = DateTime.now().difference(_sessionStartTime).inSeconds;
    _emitFeature('session_duration', sessionDuration);
  }

  double _calculateEngagement(int seconds) {
    if (seconds < 5) return 0.0; // Bounce
    if (seconds < 30) return 0.3; // Skim
    if (seconds < 120) return 0.7; // Read
    return 1.0; // Deep Dive
  }

  void _emitFeature(String name, dynamic value) {
    _featureStream.add({
      'feature_name': name,
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    _featureStream.close();
  }
}
