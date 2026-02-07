import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'sync_events_table.dart';

part 'sync_database.g.dart';

// The Enterprise Event Journal Database.
// 
// Uses Drift (SQLite) to store immutable Sync Events.
// Encrypted storage should be applied at the file level or via SQLCipher (Phase 2).
@DriftDatabase(tables: [SyncEvents])
class SyncDatabase extends _$SyncDatabase {
  SyncDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;


  Future<int> appendEvent(SyncEventsCompanion event) {
    return into(syncEvents).insert(event);
  }


  Future<List<SyncEvent>> getPendingEvents({int limit = 50}) {
    return (select(syncEvents)
      ..where((t) => t.status.equals(0))
      ..orderBy([(t) => OrderingTerm(expression: t.localVersion)])
      ..limit(limit))
      .get();
  }
  

  Future<void> markEventsAsSynced(List<String> ids) {
    return (update(syncEvents)..where((t) => t.id.isIn(ids)))
        .write(const SyncEventsCompanion(status: Value(1))); 
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sync_journal.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
