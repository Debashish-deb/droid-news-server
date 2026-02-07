
class VectorClock {

  VectorClock(this.versions);
  final Map<String, int> versions;
  
  // Implements logical clock increment
  VectorClock increment(String nodeId) {
    final newVersions = Map<String, int>.from(versions);
    newVersions[nodeId] = (newVersions[nodeId] ?? 0) + 1;
    return VectorClock(newVersions);
  }

  // Merges with another vector clock (Maximum of each component)
  VectorClock merge(VectorClock other) {
    final newVersions = Map<String, int>.from(versions);
    other.versions.forEach((node, version) {
      final current = newVersions[node] ?? 0;
      if (version > current) {
        newVersions[node] = version;
      }
    });
    return VectorClock(newVersions);
  }

  // Returns true if this clock is strictly greater than the other
  bool isGreater(VectorClock other) {
    bool atLeastOneGreater = false;
    for (final node in {...versions.keys, ...other.versions.keys}) {
      final v1 = versions[node] ?? 0;
      final v2 = other.versions[node] ?? 0;
      if (v1 < v2) return false;
      if (v1 > v2) atLeastOneGreater = true;
    }
    return atLeastOneGreater;
  }
  
  Map<String, int> toMap() => versions;
}

enum SyncOperation {
  insert,
  update,
  delete
}

class SyncEvent { // Event schema version

  SyncEvent({
    required this.entityId, required this.entityType, required this.operation, required this.payloadJson, required this.timestamp, this.id,
    this.sequenceNumber,
    this.version = 1,
  });
  final int? id; // Local auto-increment ID
  final String entityId;
  final String entityType;
  final SyncOperation operation;
  final String payloadJson;
  final DateTime timestamp;
  final int? sequenceNumber; // Strict ordering from server
  final int version;
}

