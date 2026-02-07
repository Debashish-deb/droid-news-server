import '../persistence/app_database.dart';
import 'sync_types.dart';
import 'package:drift/drift.dart' as drift;
import 'package:injectable/injectable.dart';

@lazySingleton
class EventJournalService {

  EventJournalService(this._db);
  final AppDatabase _db;

  /// Records a change event transactionally.
  Future<void> logEvent(SyncEvent event) async {
    await _db.transaction(() async {
      // Get the next sequence number for this entity type
      final lastEvent = await (_db.select(_db.syncJournal)
            ..where((tbl) => tbl.entityType.equals(event.entityType))
            ..orderBy([(t) => drift.OrderingTerm(expression: t.sequenceNumber, mode: drift.OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();

      final nextSequence = (lastEvent?.sequenceNumber ?? 0) + 1;

      await _db.into(_db.syncJournal).insert(
        SyncJournalCompanion(
          entityId: drift.Value(event.entityId),
          entityType: drift.Value(event.entityType),
          operation: drift.Value(event.operation.name),
          payloadJson: drift.Value(event.payloadJson),
          createdAt: drift.Value(event.timestamp),
          syncStatus: const drift.Value(0), // Pending
          sequenceNumber: drift.Value(nextSequence),
          eventVersion: drift.Value(event.version),
        ),
      );
    });
  }

  /// Create a snapshot for an entity type to prune the journal.
  Future<void> createSnapshot(String entityType, String snapshotData) async {
    await _db.transaction(() async {
      final lastEvent = await (_db.select(_db.syncJournal)
            ..where((tbl) => tbl.entityType.equals(entityType))
            ..orderBy([(t) => drift.OrderingTerm(expression: t.sequenceNumber, mode: drift.OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();

      if (lastEvent == null) return;

      await _db.into(_db.syncSnapshots).insert(
        SyncSnapshotsCompanion(
          entityType: drift.Value(entityType),
          lastSequenceNumber: drift.Value(lastEvent.sequenceNumber ?? 0),
          snapshotJson: drift.Value(snapshotData),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      // Prune journal events that are now part of the snapshot
      await (_db.delete(_db.syncJournal)
            ..where((tbl) => tbl.entityType.equals(entityType))
            ..where((tbl) => tbl.sequenceNumber.isSmallerOrEqualValue(lastEvent.sequenceNumber ?? 0)))
          .go();
    });
  }

  /// Fetch pending events for batch upload
  Future<List<SyncEvent>> getPendingEvents() async {
    final query = _db.select(_db.syncJournal)
      ..where((tbl) => tbl.syncStatus.equals(0))
      ..orderBy([(t) => drift.OrderingTerm(expression: t.sequenceNumber)]);
      
    final rows = await query.get();
    
    return rows.map((row) => SyncEvent(
      id: row.id,
      entityId: row.entityId,
      entityType: row.entityType,
      operation: SyncOperation.values.firstWhere((e) => e.name == row.operation),
      payloadJson: row.payloadJson,
      timestamp: row.createdAt,
      sequenceNumber: row.sequenceNumber,
      version: row.eventVersion,
    )).toList();
  }

  /// Mark events as synced
  Future<void> markAsSynced(List<int> eventIds) async {
    await (_db.update(_db.syncJournal)
      ..where((tbl) => tbl.id.isIn(eventIds))
    ).write(
      const SyncJournalCompanion(syncStatus: drift.Value(1)),
    );
  }
}

