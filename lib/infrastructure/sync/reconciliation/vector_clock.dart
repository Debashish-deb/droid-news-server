/// Logical Clock for distributed system ordering.
/// 
/// Format: { "deviceId": version }
class VectorClock {

  const VectorClock(this.timestamps);

  factory VectorClock.empty() => const VectorClock({});

  factory VectorClock.fromJson(Map<String, dynamic> json) {
    return VectorClock(Map<String, int>.from(json));
  }
  final Map<String, int> timestamps;

  Map<String, int> toJson() => timestamps;

  /// Increments the clock for the given device.
  VectorClock increment(String deviceId) {
    final newTimestamps = Map<String, int>.from(timestamps);
    newTimestamps[deviceId] = (newTimestamps[deviceId] ?? 0) + 1;
    return VectorClock(newTimestamps);
  }

  /// Merges two vector clocks (CRDT logic).
  /// Takes the max of each component.
  VectorClock merge(VectorClock other) {
    final newTimestamps = Map<String, int>.from(timestamps);
    
    other.timestamps.forEach((device, otherTime) {
      final myTime = newTimestamps[device] ?? 0;
      if (otherTime > myTime) {
        newTimestamps[device] = otherTime;
      }
    });

    return VectorClock(newTimestamps);
  }

  /// Returns true if this clock happened BEFORE other.
  /// (Strictly less than in all concurrent dimensions)
  bool isBefore(VectorClock other) {
    bool strictInequalityFound = false;

 
    final allDevices = {...timestamps.keys, ...other.timestamps.keys};

    for (final device in allDevices) {
      final myTime = timestamps[device] ?? 0;
      final otherTime = other.timestamps[device] ?? 0;

      if (myTime > otherTime) return false;
      if (myTime < otherTime) strictInequalityFound = true;
    }

    return strictInequalityFound;
  }
}
