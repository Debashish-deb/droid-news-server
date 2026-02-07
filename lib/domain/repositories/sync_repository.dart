import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';

abstract class SyncRepository {
  /// Triggers a full synchronization cycle.
  Future<Either<AppFailure, void>> syncNow();

  /// Queues an event for synchronization.
  Future<Either<AppFailure, void>> queueEvent(Map<String, dynamic> eventData);
}
