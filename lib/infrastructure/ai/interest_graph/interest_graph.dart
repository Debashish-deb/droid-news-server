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
  /// Logic: `new_weight = (old_weight * decay) + (learning_rate * signal)`
  void update(String type, String id, double signalStrength) {
    _applyDecay();

    final map = type == 'topic' ? topics : entities;
    final oldWeight = map[id] ?? 0.0;
    
    const learningRate = 0.2; 
    
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
