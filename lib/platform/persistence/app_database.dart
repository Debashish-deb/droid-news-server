import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'app_schema.dart';
import 'database_config.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Articles, ReadingHistory, SyncJournal, Bookmarks, SyncSnapshots],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _repairLegacyV1Schema();
      }
      if (from < 3) {
        await _ensureCurrentArticleColumns();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _repairLegacyV1Schema() async {
    await _ensureTable('reading_history', '''
      CREATE TABLE IF NOT EXISTS reading_history (
        article_id TEXT NOT NULL REFERENCES articles(id),
        read_at INTEGER NOT NULL,
        time_spent_seconds INTEGER NOT NULL DEFAULT 0,
        scroll_percentage REAL NOT NULL DEFAULT 0.0,
        PRIMARY KEY(article_id)
      )
      ''');
    await _ensureTable('bookmarks', '''
      CREATE TABLE IF NOT EXISTS bookmarks (
        article_id TEXT NOT NULL REFERENCES articles(id),
        created_at INTEGER NOT NULL,
        PRIMARY KEY(article_id)
      )
      ''');
    await _ensureTable('sync_journal', '''
      CREATE TABLE IF NOT EXISTS sync_journal (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0,
        sequence_number INTEGER,
        event_version INTEGER NOT NULL DEFAULT 1
      )
      ''');
    await _ensureTable('sync_snapshots', '''
      CREATE TABLE IF NOT EXISTS sync_snapshots (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        last_sequence_number INTEGER NOT NULL,
        snapshot_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
      ''');
    await _ensureCurrentArticleColumns();
    await _ensureColumnExists(
      tableName: 'sync_journal',
      columnName: 'sequence_number',
      columnDefinition: 'INTEGER',
    );
    await _ensureColumnExists(
      tableName: 'sync_journal',
      columnName: 'event_version',
      columnDefinition: 'INTEGER NOT NULL DEFAULT 1',
    );
  }

  Future<void> _ensureCurrentArticleColumns() async {
    await _ensureColumnExists(
      tableName: 'articles',
      columnName: 'description',
      columnDefinition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumnExists(
      tableName: 'articles',
      columnName: 'content',
      columnDefinition: 'TEXT',
    );
    await _ensureColumnExists(
      tableName: 'articles',
      columnName: 'image_url',
      columnDefinition: 'TEXT',
    );
    await _ensureColumnExists(
      tableName: 'articles',
      columnName: 'language',
      columnDefinition: "TEXT NOT NULL DEFAULT 'en'",
    );
    await _ensureColumnExists(
      tableName: 'articles',
      columnName: 'category',
      columnDefinition: 'TEXT',
    );
    await _ensureColumnExists(
      tableName: 'articles',
      columnName: 'tags',
      columnDefinition: 'TEXT',
    );
    await _ensureColumnExists(
      tableName: 'articles',
      columnName: 'embedding',
      columnDefinition: 'BLOB',
    );
  }

  Future<void> _ensureTable(String tableName, String createSql) async {
    if (await _tableExists(tableName)) {
      return;
    }
    await customStatement(createSql);
  }

  Future<void> _ensureColumnExists({
    required String tableName,
    required String columnName,
    required String columnDefinition,
  }) async {
    if (await _columnExists(tableName: tableName, columnName: columnName)) {
      return;
    }
    await customStatement(
      'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
    );
  }

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      variables: <Variable>[Variable.withString(tableName)],
    ).get();
    return result.isNotEmpty;
  }

  Future<bool> _columnExists({
    required String tableName,
    required String columnName,
  }) async {
    final result = await customSelect('PRAGMA table_info($tableName)').get();
    return result.any((row) => row.data['name'] == columnName);
  }

  /// Cleans up staled articles older than the specified duration.
  Future<int> cleanupOldArticles({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final cutoffDate = DateTime.now().subtract(maxAge);

    // Using drift query builder to delete old articles
    final deletedCount = await (delete(
      articles,
    )..where((tbl) => tbl.publishedAt.isSmallerThanValue(cutoffDate))).go();

    return deletedCount;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    await setupSqliteLibrary();
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'enterprise_news.sqlite'));

    return NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA synchronous = NORMAL;');
      },
    );
  });
}
