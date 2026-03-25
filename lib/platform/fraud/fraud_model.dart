
enum SignalType {
  velocity,       // Too many actions in short time
  integrity,      // Device integrity violation
  impossibleTravel, // Geo distance impossible
  replayAttack,   // Token/Receipt reuse
  deviceMismatch  // Session device != Current device
}

enum RiskLevel {
  none,
  low,
  medium,
  high,
  critical
}

class FraudSignal {

  const FraudSignal({
    required this.id,
    required this.type,
    required this.score,
    required this.metadata,
    required this.timestamp,
  });
  final String id;
  final SignalType type;
  final double score; // 0.0 to 1.0 (1.0 = High Fraud Probability)
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
}
