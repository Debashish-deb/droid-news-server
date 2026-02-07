/// Abstract definition of Sync Conflict Resolution Rules.
///
/// This defines how the system resolves collisions between local state
/// and server state.
abstract class SyncConflictPolicy<T> {
  /// Resolves a conflict between a local entity and a server entity.
  ///
  /// Returns the resolved entity.
  T resolve({
    required T localState,
    required T serverState,
    required DateTime localTimestamp,
    required DateTime serverTimestamp,
  });
}

/// Enumeration of standard resolution strategies.
enum ConflictStrategy {
  serverWins,
  clientWins,
  latestWins,
  unionMerge,
  manualMerge
}
