
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../identity/device_registry.dart';
import 'fraud_model.dart';

abstract class SignalCollector {
  Future<void> captureSignal(SignalType type, {double impact = 0.5, Map<String, dynamic>? data});
  Future<List<FraudSignal>> getRecentSignals({Duration lookback = const Duration(hours: 24)});
  Future<RiskLevel> evaluateRisk();
}

class SignalCollectorImpl implements SignalCollector {
  
  SignalCollectorImpl(this._deviceRegistry);
  final DeviceRegistry _deviceRegistry;
  
  // In memory buffer for now. Enterprise version would use SQFLite/Drift event journal.
  final List<FraudSignal> _signalBuffer = [];

  @override
  Future<void> captureSignal(SignalType type, {double impact = 0.5, Map<String, dynamic>? data}) async {
    final signal = FraudSignal(
      id: const Uuid().v4(),
      type: type,
      score: impact,
      metadata: data ?? {},
      timestamp: DateTime.now(),
    );
    
    _signalBuffer.add(signal);
    
    // Prune old signals
    if (_signalBuffer.length > 100) {
      _signalBuffer.removeAt(0);
    }
    
    print('🚨 FRAUD SIGNAL CAPTURED: ${type.name} (Risk: $impact)');
  }

  @override
  Future<List<FraudSignal>> getRecentSignals({Duration lookback = const Duration(hours: 24)}) async {
    final cutoff = DateTime.now().subtract(lookback);
    return _signalBuffer.where((s) => s.timestamp.isAfter(cutoff)).toList();
  }

  @override
  Future<RiskLevel> evaluateRisk() async {
    // 1. Check for integrity failures
    final integrity = await _deviceRegistry.bindDevice('check-only'); // Reuse binding check logic
    if (integrity.trustScore < 0.2) return RiskLevel.critical;
    if (integrity.isRooted || integrity.isEmulator) return RiskLevel.high;

    // 2. Calculate cumulative risk from recent signals
    final recent = await getRecentSignals(lookback: const Duration(minutes: 60));
    final double totalScore = recent.fold(0.0, (sum, signal) => sum + signal.score);

    if (totalScore > 5.0) return RiskLevel.critical;
    if (totalScore > 3.0) return RiskLevel.high;
    if (totalScore > 1.0) return RiskLevel.medium;
    if (totalScore > 0.0) return RiskLevel.low;
    
    return RiskLevel.none;
  }
}
