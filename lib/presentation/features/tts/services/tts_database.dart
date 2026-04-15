import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models/speech_chunk.dart';

import '../../../../core/telemetry/structured_logger.dart';

class TtsDatabase {
  TtsDatabase(this._logger) {
    _instances.add(this);
  }
  final StructuredLogger _logger;
  static const String _databaseFileName = 'tts_cache.db';
  static final Set<TtsDatabase> _instances = <TtsDatabase>{};
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseFileName);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE audio_chunks (
        id INTEGER PRIMARY KEY,
        text_hash TEXT NOT NULL,
        text_content TEXT NOT NULL,
        language TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size_bytes INTEGER DEFAULT 0,
        duration_ms INTEGER,
        created_at TEXT NOT NULL,
        last_accessed_at TEXT,
        access_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_text_hash ON audio_chunks(text_hash)');

    await _createSessionsTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // For simplicity in this cache DB, we drop and recreate
      await db.execute('DROP TABLE IF EXISTS audio_chunks');
      await _createDB(db, newVersion);
    }
  }

  Future<void> _createSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tts_sessions (
        session_id TEXT PRIMARY KEY,
        article_id TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        session_data TEXT NOT NULL
      )
    ''');
    try {
      await db.execute(
        'CREATE INDEX idx_article_id ON tts_sessions(article_id)',
      );
    } catch (e, stack) {
      try {
        _logger.warning('Failed to create index', e, stack);
      } catch (_) {}
    }
  }

  String _generateHash(String text, String language, String profileKey) {
    final bytes = utf8.encode('$text|$language|$profileKey');
    return sha256.convert(bytes).toString();
  }

  Future<SpeechChunk?> getCachedChunk(
    String text,
    String language, {
    String profileKey = '',
  }) async {
    final db = await database;
    final hash = _generateHash(text, language, profileKey);

    final maps = await db.query(
      'audio_chunks',
      columns: ['file_path', 'duration_ms', 'file_size_bytes'],
      where: 'text_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final path = maps.first['file_path'] as String;
      final duration = maps.first['duration_ms'] as int?;

      if (await File(path).exists()) {
        _updateAccessStats(hash);

        final chunk = SpeechChunk(
          id: -1,
          text: text,
          startIndex: 0,
          endIndex: 0,
          language: language,
          synthesisProfileKey: profileKey,
          audioPath: path,
          durationMs: duration,
          fileSizeBytes: maps.first['file_size_bytes'] as int? ?? 0,
          status: ChunkStatus.cached,
        );
        return chunk;
      } else {
        await db.delete(
          'audio_chunks',
          where: 'text_hash = ?',
          whereArgs: [hash],
        );
      }
    }
    return null;
  }

  Future<void> _updateAccessStats(String hash) async {
    try {
      final db = await database;
      await db.rawUpdate(
        '''
        UPDATE audio_chunks 
        SET access_count = access_count + 1, last_accessed_at = ? 
        WHERE text_hash = ?
      ''',
        [DateTime.now().toIso8601String(), hash],
      );
    } catch (e, stack) {
      _logger.warning('DB Error updating stats', e, stack);
    }
  }

  Future<void> cacheChunk(
    String text,
    String language,
    String filePath,
    int? durationMs,
    int fileSizeBytes, {
    String profileKey = '',
  }) async {
    final db = await database;
    final hash = _generateHash(text, language, profileKey);
    final now = DateTime.now().toIso8601String();

    await db.insert('audio_chunks', {
      'text_hash': hash,
      'text_content': text,
      'language': language,
      'file_path': filePath,
      'file_size_bytes': fileSizeBytes,
      'duration_ms': durationMs,
      'created_at': now,
      'last_accessed_at': now,
      'access_count': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveSession(
    String sessionId,
    String articleId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    await db.insert('tts_sessions', {
      'session_id': sessionId,
      'article_id': articleId,
      'updated_at': DateTime.now().toIso8601String(),
      'session_data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'tts_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      try {
        return jsonDecode(maps.first['session_data'] as String);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLastSessionForArticle(
    String articleId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'tts_sessions',
      where: 'article_id = ?',
      whereArgs: [articleId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      try {
        return jsonDecode(maps.first['session_data'] as String);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'tts_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<int> getCacheSizeBytes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(file_size_bytes) FROM audio_chunks',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getEvictionCandidates(int limit) async {
    final db = await database;
    final maps = await db.query(
      'audio_chunks',
      columns: ['file_path'],
      orderBy: 'last_accessed_at ASC',
      limit: limit,
    );
    return maps.map((m) => m['file_path'] as String).toList();
  }

  Future<void> removeChunksByPath(List<String> paths) async {
    final db = await database;

    final batch = db.batch();
    for (final path in paths) {
      batch.delete('audio_chunks', where: 'file_path = ?', whereArgs: [path]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete('audio_chunks');
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  static Future<void> closeAll() async {
    for (final db in List<TtsDatabase>.of(_instances)) {
      await db.close();
    }
  }

  static Future<void> deleteStorage() async {
    await closeAll();

    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, _databaseFileName));

    final documentsDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(join(documentsDir.path, 'tts_cache'));
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
}
