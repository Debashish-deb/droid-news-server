/// Represents an atomic, immutable event in the system.
/// 
/// Used for Event Sourcing synchronization.
class SyncEvent {

  const SyncEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.timestamp,
    required this.hash,
    required this.localVersion,
    required this.deviceId,
  });
  /// Unique ID of the event (UUID v4)
  final String id;

  /// The domain entity type (e.g., 'article', 'settings')
  final String entityType;
  
  /// The ID of the specific entity being acted upon
  final String entityId;

  /// The action performed (e.g., 'create', 'update', 'delete', 'bookmark')
  final String action;

  /// The JSON data associated with the change
  final Map<String, dynamic> payload;

  /// When the event occurred (client time)
  final DateTime timestamp;

  /// SHA-256 hash of (prev_hash + this_event_data) for tamper evidence
  final String hash;

  /// Incremental counter for local ordering
  final int localVersion;

  /// Device ID that generated the event
  final String deviceId;

  /// Creates a copy of this event with identifying database fields potentially populated
  SyncEvent copyWith({
    String? id,
    String? hash,
    int? localVersion,
  }) {
    return SyncEvent(
      id: id ?? this.id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
      timestamp: timestamp,
      hash: hash ?? this.hash,
      localVersion: localVersion ?? this.localVersion,
      deviceId: deviceId,
    );
  }
}
