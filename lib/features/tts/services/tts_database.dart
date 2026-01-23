import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/speech_chunk.dart';

class TtsDatabase {
  static final TtsDatabase instance = TtsDatabase._init();
  static Database? _database;

  TtsDatabase._init();

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
      version: 1, 
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE audio_chunks (
        id INTEGER PRIMARY KEY,
        text_hash TEXT NOT NULL,
        language TEXT NOT NULL,
        file_path TEXT NOT NULL,
        duration_ms INTEGER,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Index for faster lookups
    await db.execute('CREATE INDEX idx_text_hash ON audio_chunks(text_hash)');
  }

  String _generateHash(String text, String language) {
    // simple hash for now, better to use crypto md5 in production
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
      
      // Verify file exists
      if (await File(path).exists()) {
        final chunk = SpeechChunk(
          id: -1, // Placeholder
          text: text,
          startIndex: 0,
          endIndex: 0,
          language: language,
          audioPath: path,
          durationMs: duration,
        );
        return chunk;
      } else {
        // Cleanup orphaned record
        await db.delete('audio_chunks', where: 'text_hash = ?', whereArgs: [hash]);
      }
    }
    return null;
  }

  Future<void> cacheChunk(String text, String language, String filePath, int? durationMs) async {
    final db = await database;
    final hash = _generateHash(text, language);
    
    await db.insert(
      'audio_chunks',
      {
        'text_hash': hash,
        'language': language,
        'file_path': filePath,
        'duration_ms': durationMs,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('audio_chunks');
    // Actual file deletion handled by AudioCacheManager
  }
}
