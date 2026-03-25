import '../entities/tts_chunk.dart';
import '../entities/tts_config.dart';
import '../entities/voice_profile.dart';

abstract class TtsRepository {
  Future<void> init();
  Future<void> play(List<TtsChunk> chunks, int startIndex);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(int chunkIndex);
  
  Future<void> updateConfig(TtsConfig config);
  Future<List<VoiceProfile>> getAvailableVoices();
  
  Stream<int> get currentChunkIndex;
  Stream<double> get progress;
}
