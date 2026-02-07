
import 'package:drift/drift.dart';

// Tables

class Articles extends Table {
  TextColumn get id => text()(); // Canonical ID
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get url => text()();
  TextColumn get content => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get source => text()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  DateTimeColumn get publishedAt => dateTime()();
  TextColumn get category => text().nullable()();
  
  // Vector embeddings for AI (Blob for quantized data)
  BlobColumn get embedding => blob().nullable()(); 

  @override
  Set<Column> get primaryKey => {id};
}

class ReadingHistory extends Table {
  TextColumn get articleId => text().references(Articles, #id)();
  DateTimeColumn get readAt => dateTime()();
  IntColumn get timeSpentSeconds => integer().withDefault(const Constant(0))();
  RealColumn get scrollPercentage => real().withDefault(const Constant(0.0))();
  
  @override
  Set<Column> get primaryKey => {articleId};
}

class Bookmarks extends Table {
  TextColumn get articleId => text().references(Articles, #id)();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {articleId};
}

class SyncJournal extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get entityType => text()(); // 'article_read', 'favorite_add'
  TextColumn get operation => text()(); // 'INSERT', 'UPDATE', 'DELETE'
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))(); // 0=Pending, 1=Synced
  
  // Enterprise Enhancements
  IntColumn get sequenceNumber => integer().nullable()(); // Strict ordering
  IntColumn get eventVersion => integer().withDefault(const Constant(1))(); // Schema versioning
}

class SyncSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  IntColumn get lastSequenceNumber => integer()();
  TextColumn get snapshotJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

