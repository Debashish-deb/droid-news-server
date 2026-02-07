import 'dart:async';
import '../collection/ai_event_collector.dart';

/// Transforms raw event signals into high-level features for the AI model.
/// 
/// output: Stream of [AIFeatureVector]
class FeatureEngineeringService {

  FeatureEngineeringService(this._collector) {
    _collector.eventStream.listen(_processEvent);
    _sessionStartTime = DateTime.now();
  }
  final AIEventCollector _collector;
  
  int _sessionDepth = 0;
  DateTime? _sessionStartTime;
  final Map<String, int> _topicCounts = {};

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
    
    if (event.containsKey('topic')) {
      final topic = event['topic'];
      _topicCounts[topic] = (_topicCounts[topic] ?? 0) + 1;
    }

    _emitFeature('session_depth', _sessionDepth);
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
