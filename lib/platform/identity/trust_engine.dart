import 'package:injectable/injectable.dart';
import 'device_registry.dart';

enum TrustLevel {
  high,   // Score >= 0.8
  medium, // Score >= 0.5
  low,    // Score < 0.5
  blocked // Score == 0.0
}

abstract class TrustEngine {
  Future<double> calculateTrustScore(String deviceId);
  Future<TrustLevel> evaluateTrust(String deviceId);
}

@LazySingleton(as: TrustEngine)
class TrustEngineImpl implements TrustEngine {

  TrustEngineImpl(this._deviceRegistry);
  final DeviceRegistry _deviceRegistry;

  @override
  Future<double> calculateTrustScore(String deviceId) async {
    // 1. Get basic device integrity
    // In a real app, this would check backend risk signals, IP reputation, etc.
    final bool verified = await _deviceRegistry.verifyDevice(deviceId);
    if (!verified) return 0.0;
    
    // For now, we assume a connected device that passes verification is "Trusted" 
    // enough to start with 1.0, effectively verifying the device binding matches.
    return 1.0; 
  }

  @override
  Future<TrustLevel> evaluateTrust(String deviceId) async {
    final score = await calculateTrustScore(deviceId);
    
    if (score >= 0.8) return TrustLevel.high;
    if (score >= 0.5) return TrustLevel.medium;
    if (score > 0.0) return TrustLevel.low;
    return TrustLevel.blocked;
  }
}
