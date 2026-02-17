
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'app_schema.dart';


part 'app_database.g.dart';


@DriftDatabase(tables: [Articles, ReadingHistory, SyncJournal, Bookmarks, SyncSnapshots])
class AppDatabase extends _$AppDatabase {
  
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'enterprise_news.sqlite'));
    
    // Enterprise Hardening: We use NativeDatabase for SQLite operations.
    // In a production build with sqlcipher_flutter_libs, use NativeDatabase.cipher
    // with a key derived from SecurePrefs.
    
    // final secureKey = await SecurePrefs.instance.getString('db_encryption_key');
    // if (secureKey == null) {
    //   final newKey = ... generate key ...
    //   await SecurePrefs.instance.putString('db_encryption_key', newKey);
    // }
    
    return NativeDatabase(
      file,
      setup: (db) {
        // Performance & Reliability Hardening
        db.execute('PRAGMA journal_mode = WAL;'); // Write-Ahead Logging for concurrency
        db.execute('PRAGMA synchronous = NORMAL;');
      },
    );
  });
}
