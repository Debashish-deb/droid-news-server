import '../models/speech_chunk.dart';
import '../models/tts_session.dart';

/// Repository interface for TTS data operations
/// 
/// Abstracts data layer (cache, database, file system)
/// from business logic for testability and flexibility.
abstract class TtsRepository {
  /// Cache operations
  Future<void> cacheChunk(SpeechChunk chunk, String audioPath);
  Future<SpeechChunk?> getCachedChunk(SpeechChunk chunk);
 Future<List<SpeechChunk>> getCachedChunksForArticle(String articleId);
  Future<void> deleteCachedChunk(String chunkId);
  Future<void> clearOldCache({Duration maxAge});
  
  /// Session operations
  Future<void> saveSession(TtsSession session);
  Future<TtsSession?> loadSession(String sessionId);
  Future<TtsSession?> getLastSession();
  Future<void> deleteSession(String sessionId);
  
  /// Analytics
  Future<void> recordPlayback(String articleId, int chunkIndex);
  Future<void> recordError(String articleId, String error);
  
  /// Cache management
  Future<int> getCacheSizeBytes();
  Future<void> evictLeastRecentlyUsed(int targetSizeBytes);
}
