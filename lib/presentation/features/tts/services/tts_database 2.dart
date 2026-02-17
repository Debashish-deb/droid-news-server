import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';

import 'package:bdnewsreader/core/telemetry/structured_logger.dart';

class TtsDatabase {
  static Database? _database;

  TtsDatabase(this._logger);
  final StructuredLogger _logger;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tts_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 3, 
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
    if (oldVersion < 3) {
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
      await db.execute('CREATE INDEX idx_article_id ON tts_sessions(article_id)');
    } catch (e, stack) {
      try {
        _logger.warning('Failed to create index', e, stack);
      } catch (_) {}
    }
  }

  String _generateHash(String text, String language) {
    return '${text.hashCode}_$language';
  }

  Future<SpeechChunk?> getCachedChunk(String text, String language) async {
    final db = await database;
    final hash = _generateHash(text, language);
    
    final maps = await db.query(
      'audio_chunks',
      columns: ['file_path', 'duration_ms'],
      where: 'text_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final path = maps.first['file_path'] as String;
      final duration = maps.first['duration_ms'] as int?;
      
    
      if (await File(path).exists()) {
        final chunk = SpeechChunk(
          id: -1,
          text: text,
          startIndex: 0,
          endIndex: 0,
          language: language,
          audioPath: path,
          durationMs: duration,
          status: ChunkStatus.cached, 
        );
        return chunk;
      } else {
        
        await db.delete('audio_chunks', where: 'text_hash = ?', whereArgs: [hash]);
      }
    }
    return null;
  }
  
  Future<void> _updateAccessStats(String hash) async {
    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE audio_chunks 
        SET access_count = access_count + 1, last_accessed_at = ? 
        WHERE text_hash = ?
      ''', [DateTime.now().toIso8601String(), hash]);
    } catch (e, stack) {
      try {
        _logger.warning('DB Error updating stats', e, stack);
      } catch (_) {}
    }
  }

  Future<void> cacheChunk(String text, String language, String filePath, int? durationMs) async {
    final db = await database;
    final hash = _generateHash(text, language);
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'audio_chunks',
      {
        'text_hash': hash,
        'text_content': text,
        'language': language,
        'file_path': filePath,
        'duration_ms': durationMs,
        'created_at': now,
        'last_accessed_at': now,
        'access_count': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  

  
  Future<void> saveSession(String sessionId, String articleId, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'tts_sessions',
      {
        'session_id': sessionId,
        'article_id': articleId,
        'updated_at': DateTime.now().toIso8601String(),
        'session_data': jsonEncode(data),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
  
  Future<Map<String, dynamic>?> getLastSessionForArticle(String articleId) async {
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
    await db.delete('tts_sessions', where: 'session_id = ?', whereArgs: [sessionId]);
  }
  

  
  Future<int> getCacheSizeBytes() async {
  
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM audio_chunks')) ?? 0;
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
}
