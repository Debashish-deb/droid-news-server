
class DeviceIntegrity {

  const DeviceIntegrity({
    required this.deviceId,
    required this.isRooted,
    required this.isEmulator,
    required this.trustScore,
    required this.lastVerifiedAt,
  });

  factory DeviceIntegrity.unknown(String deviceId) {
    return DeviceIntegrity(
      deviceId: deviceId,
      isRooted: false,
      isEmulator: false,
      trustScore: 0.5, // Neutral start
      lastVerifiedAt: DateTime.now(),
    );
  }
  final String deviceId;
  final bool isRooted;
  final bool isEmulator;
  final double trustScore; // 0.0 to 1.0
  final DateTime lastVerifiedAt;
  
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'isRooted': isRooted,
      'isEmulator': isEmulator,
      'trustScore': trustScore,
      'lastVerifiedAt': lastVerifiedAt.toIso8601String(),
    };
  }
}

abstract class DeviceRegistry {
  Future<String> getDeviceId();
  Future<DeviceIntegrity> bindDevice(String userId);
  Future<bool> verifyDevice(String deviceId);
}
