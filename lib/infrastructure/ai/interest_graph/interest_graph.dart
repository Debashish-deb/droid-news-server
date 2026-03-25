import 'dart:math';

/// A living, breathing model of the User's interests.
/// 
/// Uses a Decay function to prioritize recent interests while retaining 
/// long-term preferences.
class InterestGraph {

  InterestGraph({
    required this.topics,
    required this.entities,
    required this.lastUpdated,
  });

  factory InterestGraph.empty() {
    return InterestGraph(
      topics: {}, 
      entities: {}, 
      lastUpdated: DateTime.now()
    );
  }
  final Map<String, double> topics;
  
  final Map<String, double> entities;
  
  DateTime lastUpdated;

  /// Updates the graph with a new signal.
  /// 
  /// Logic: `new_weight = decayed_old_weight + (learning_rate * signal)`
  void update({
    required String type, 
    required String id, 
    required double signalStrength,
    bool isBehavioral = false,
  }) {
    _applyDecay();

    final map = type == 'topic' ? topics : entities;
    final oldWeight = map[id] ?? 0.0;
    
    // Direct signals (like, share) have higher learning rate than 
    // passive behavioral signals (dwell, scroll)
    final learningRate = isBehavioral ? 0.05 : 0.2; 
    
    final newWeight = oldWeight + (learningRate * signalStrength);
    
    map[id] = min(newWeight, 1.0);
    lastUpdated = DateTime.now();
  }

  void _applyDecay() {
    final now = DateTime.now();
    final hoursPassed = now.difference(lastUpdated).inHours;
    
    if (hoursPassed == 0) return;

    final decay = pow(0.98, hoursPassed);

    topics.updateAll((key, val) => val * decay);
    entities.updateAll((key, val) => val * decay);
    
    topics.removeWhere((key, val) => val < 0.05);
    entities.removeWhere((key, val) => val < 0.05);
  }
}

