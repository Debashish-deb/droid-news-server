import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_session.dart';
import 'package:bdnewsreader/presentation/features/tts/core/text_cleaner.dart';
import 'package:bdnewsreader/presentation/features/tts/core/chunk_engine.dart';
import 'package:bdnewsreader/core/telemetry/structured_logger.dart';

// Pipeline orchestrator for TTS flow
// 
// Coordinates the complete TTS pipeline:
// 1. Clean text
// 2. Chunk into speech segments
// 3. Generate audio (delegated to TtsService)
// 4. Cache results
// 5. Trigger playback
// 
// This is the "conductor" that ensures proper flow and error handling.
class PipelineOrchestrator {
  final StructuredLogger _logger;

  PipelineOrchestrator(this._logger);

 
  Future<PipelineResult> processArticle({
    required String articleId,
    required String title,
    required String content,
    String language = 'en',
  }) async {
    try {
      _logger.info('[Pipeline] Step 1: Cleaning text');
      final cleanedContent = TextCleaner.clean(content);
      
      if (cleanedContent.isEmpty) {
        return PipelineResult.error('Article content is empty after cleaning');
      }
      
      _logger.info('[Pipeline] Step 2: Creating chunks');
      final chunks = ChunkEngine.createChunks(
        cleanedContent,
        language: language,
        title: title,
      );
      
      if (chunks.isEmpty) {
        return PipelineResult.error('No chunks generated');
      }
      
      final quality = ChunkEngine.analyzeQuality(chunks);
      _logger.info('[Pipeline] Chunk quality: $quality');
      
      final session = TtsSession.create(
        articleId: articleId,
        articleTitle: title,
      ).copyWith(
        totalChunks: chunks.length,
        state: TtsSessionState.chunking,
      );
      
      _logger.info('[Pipeline] ✅ Pipeline complete: ${chunks.length} chunks');
      
      return PipelineResult.success(
        session: session,
        chunks: chunks,
        quality: quality,
      );
    } catch (e, stack) {
      _logger.error('[Pipeline] ❌ Error: $e', stack);
      return PipelineResult.error('Pipeline failed: $e');
    }
  }
  
  bool validateChunk(SpeechChunk chunk) {
    if (chunk.text.isEmpty) {
      _logger.info('[Pipeline] ⚠️ Empty chunk text');
      return false;
    }
    
    if (chunk.text.length > ChunkEngine.maxChunkSize * 2) {
      _logger.info('[Pipeline] ⚠️ Chunk too large: ${chunk.text.length}');
      return false;
    }
    
    return true;
  }
  
  bool shouldRetry(SpeechChunk chunk) {
    return chunk.retryCount < 3 && chunk.status == ChunkStatus.error;
  }
  
  Duration estimateTotalDuration(List<SpeechChunk> chunks) {
    const charsPerSecond = (150 * 5) / 60;
    
    final totalChars = chunks.fold<int>(
      0,
      (sum, chunk) => sum + chunk.text.length,
    );
    
    return Duration(seconds: (totalChars / charsPerSecond).ceil());
  }
}

// Result of pipeline processing
class PipelineResult {
  final bool success;
  final TtsSession? session;
  final List<SpeechChunk>? chunks;
  final ChunkQuality? quality;
  final String? error;
  
  const PipelineResult._({
    required this.success,
    this.session,
    this.chunks,
    this.quality,
    this.error,
  });
  
  factory PipelineResult.success({
    required TtsSession session,
    required List<SpeechChunk> chunks,
    ChunkQuality? quality,
  }) {
    return PipelineResult._(
      success: true,
      session: session,
      chunks: chunks,
      quality: quality,
    );
  }
  
  factory PipelineResult.error(String message) {
    return PipelineResult._(
      success: false,
      error: message,
    );
  }
  
  @override
  String toString() {
    if (success) {
      return 'PipelineResult(success, chunks: ${chunks?.length}, quality: $quality)';
    } else {
      return 'PipelineResult(error: $error)';
    }
  }
}
