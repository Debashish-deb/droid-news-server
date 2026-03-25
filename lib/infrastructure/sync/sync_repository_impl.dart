import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/repositories/sync_repository.dart';
import 'journal/sync_database.dart';
import 'package:drift/drift.dart';

// Concrete implementation of the Sync Repository.
// 
// Manages the Event Journal and Orchestrates the Sync Pipeline.
class SyncRepositoryImpl implements SyncRepository {

  SyncRepositoryImpl(this._db);
  final SyncDatabase _db;
  final Uuid _uuid = const Uuid();

  @override
  Future<Either<AppFailure, void>> queueEvent(Map<String, dynamic> eventData) async {
    try {
      final id = _uuid.v4();
      final timestamp = DateTime.now().toIso8601String();
      final hash = sha256.convert(utf8.encode('$id$timestamp')).toString(); 

      final event = SyncEventsCompanion(
        id: Value(id),
        entityType: Value(eventData['entityType'] ?? 'unknown'),
        entityId: Value(eventData['entityId'] ?? 'unknown'),
        action: Value(eventData['action'] ?? 'unknown'),
        payload: Value(jsonEncode(eventData)),
        timestamp: Value(timestamp),
        hash: Value(hash),
        deviceId: const Value('current_device_id'), 
        status: const Value(0),
      );

      await _db.appendEvent(event);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to queue sync event: $e'));
    }
  }

  @override
  Future<Either<AppFailure, void>> syncNow() async {

    final pending = await _db.getPendingEvents();
    if (pending.isEmpty) return const Right(null);





    final ids = pending.map((e) => e.id).toList();
    await _db.markEventsAsSynced(ids);

    return const Right(null);
  }
}
