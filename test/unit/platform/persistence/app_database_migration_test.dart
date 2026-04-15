import 'dart:io';

import 'package:bdnewsreader/platform/persistence/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDatabase migration', () {
    late File dbFile;

    setUp(() async {
      dbFile = File(
        '${Directory.systemTemp.path}/app_database_migration_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );

      final legacyDb = sqlite.sqlite3.open(dbFile.path);
      legacyDb.execute('PRAGMA user_version = 1;');
      legacyDb.execute('''
        CREATE TABLE articles (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          url TEXT NOT NULL,
          source TEXT NOT NULL,
          published_at INTEGER NOT NULL
        );
      ''');
      legacyDb.dispose();
    });

    tearDown(() async {
      if (dbFile.existsSync()) {
        dbFile.deleteSync();
      }
    });

    test('heals legacy v1 installs with missing tables and columns', () async {
      final database = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => database.close());

      await database.customSelect('SELECT 1').get();

      final articleColumns = await database
          .customSelect('PRAGMA table_info(articles)')
          .get();
      final articleColumnNames = articleColumns
          .map((row) => row.data['name'])
          .whereType<String>()
          .toSet();

      expect(
        articleColumnNames,
        containsAll(<String>[
          'description',
          'content',
          'image_url',
          'language',
          'category',
          'tags',
          'embedding',
        ]),
      );

      final tables = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final tableNames = tables
          .map((row) => row.data['name'])
          .whereType<String>()
          .toSet();

      expect(
        tableNames,
        containsAll(<String>[
          'reading_history',
          'bookmarks',
          'sync_journal',
          'sync_snapshots',
        ]),
      );
    });
  });
}
