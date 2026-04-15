import '../models/speech_chunk.dart';
import '../models/tts_session.dart';

/// Storage interface for TTS cache and session persistence.
abstract class TtsStorageRepository {
  /// Cache operations
  Future<void> cacheChunk(SpeechChunk chunk, String audioPath);
  Future<SpeechChunk?> getCachedChunk(SpeechChunk chunk);
  Future<void> deleteCachedChunk(String chunkId);
  Future<void> clearOldCache({Duration maxAge});

  /// Session operations
  Future<void> saveSession(TtsSession session);
  Future<TtsSession?> loadSession(String sessionId);
  Future<TtsSession?> getLastSession();
  Future<void> deleteSession(String sessionId);

  /// Cache management
  Future<int> getCacheSizeBytes();
  Future<void> evictLeastRecentlyUsed(int targetSizeBytes);
}
