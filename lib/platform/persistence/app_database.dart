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
      if (from < 3) {
        await m.addColumn(articles, articles.tags);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
