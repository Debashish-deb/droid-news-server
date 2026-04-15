import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/models/speech_chunk.dart';
import '../../domain/models/tts_session.dart';
import '../../domain/repositories/tts_repository.dart'
    show TtsStorageRepository;
import '../../services/tts_database.dart';
import '../../services/audio_cache_manager.dart';

class TtsStorageRepositoryImpl implements TtsStorageRepository {
  TtsStorageRepositoryImpl({
    required TtsDatabase db,
    required AudioCacheManager cacheManager,
  }) : _db = db,
       _cacheManager = cacheManager;
  final TtsDatabase _db;
  final AudioCacheManager _cacheManager;

  @override
  Future<void> cacheChunk(SpeechChunk chunk, String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioPath');
      }

      final size = await file.length();

      await _db.cacheChunk(
        chunk.text,
        chunk.language,
        audioPath,
        chunk.durationMs,
        size,
        profileKey: chunk.synthesisProfileKey,
      );

      debugPrint(
        '[Repository] Cached chunk: ${chunk.id} path: $audioPath size: $size',
      );
    } catch (e) {
      debugPrint('[Repository] Failed to cache chunk: $e');
      rethrow;
    }
  }

  @override
  Future<SpeechChunk?> getCachedChunk(SpeechChunk chunk) async {
    return await _db.getCachedChunk(
      chunk.text,
      chunk.language,
      profileKey: chunk.synthesisProfileKey,
    );
  }

  Future<SpeechChunk?> getCachedChunkForChunk(SpeechChunk chunk) async {
    return await _db.getCachedChunk(
      chunk.text,
      chunk.language,
      profileKey: chunk.synthesisProfileKey,
    );
  }

  @override
  Future<void> clearOldCache({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final cutoff = now.subtract(maxAge).toIso8601String();

    final maps = await db.query(
      'audio_chunks',
      columns: ['file_path'],
      where: 'last_accessed_at < ?',
      whereArgs: [cutoff],
    );

    for (final map in maps) {
      final path = map['file_path'] as String;
      await _cacheManager.deleteFile(path);
    }

    await db.delete(
      'audio_chunks',
      where: 'last_accessed_at < ?',
      whereArgs: [cutoff],
    );
  }

  @override
  Future<void> deleteCachedChunk(String chunkId) async {
    final db = await _db.database;

    final maps = await db.query(
      'audio_chunks',
      columns: ['file_path'],
      where: 'text_hash = ?',
      whereArgs: [chunkId],
    );
    if (maps.isNotEmpty) {
      final path = maps.first['file_path'] as String;
      await _cacheManager.deleteFile(path);
      await db.delete(
        'audio_chunks',
        where: 'text_hash = ?',
        whereArgs: [chunkId],
      );
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _db.deleteSession(sessionId);
  }

  @override
  Future<void> evictLeastRecentlyUsed(int targetSizeBytes) async {
    final int currentSize = await getCacheSizeBytes();
    if (currentSize <= targetSizeBytes) return;

    final candidates = await _db.getEvictionCandidates(50);

    for (final path in candidates) {
      await _cacheManager.deleteFile(path);
      await _db.removeChunksByPath([path]);
    }
  }

  @override
  Future<int> getCacheSizeBytes() async {
    return _db.getCacheSizeBytes();
  }

  @override
  Future<TtsSession?> getLastSession() async {
    final db = await _db.database;
    final maps = await db.query(
      'tts_sessions',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      try {
        final jsonStr = maps.first['session_data'] as String;
        return TtsSession.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<TtsSession?> loadSession(String sessionId) async {
    final data = await _db.getSession(sessionId);
    if (data != null) {
      return TtsSession.fromJson(data);
    }
    return null;
  }

  @override
  Future<void> saveSession(TtsSession session) async {
    await _db.saveSession(
      session.sessionId,
      session.articleId,
      session.toJson(),
    );
  }
}
