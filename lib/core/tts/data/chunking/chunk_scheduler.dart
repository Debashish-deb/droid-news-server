import '../../domain/entities/tts_chunk.dart';
import 'sentence_tokenizer.dart';

class ChunkScheduler {
  static const int maxChunkLength = 280; // Optimal length for many TTS engines
  static const int charsPerMs = 40; // Rough heuristic for duration estimation

  static List<TtsChunk> buildChunks(String text) {
    if (text.isEmpty) return [];
    
    final sentences = SentenceTokenizer.tokenize(text);
    final chunks = <TtsChunk>[];

    var buffer = '';
    var index = 0;

    for (final sentence in sentences) {
      final trimmedSentence = sentence.trim();
      if ((buffer + trimmedSentence).length < maxChunkLength) {
        buffer += (buffer.isEmpty ? '' : ' ') + trimmedSentence;
      } else {
        if (buffer.isNotEmpty) {
          chunks.add(TtsChunk(
            index: index++,
            text: buffer.trim(),
            estimatedDuration: Duration(milliseconds: buffer.length * charsPerMs),
          ));
        }
        buffer = trimmedSentence;
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(TtsChunk(
        index: index,
        text: buffer.trim(),
        estimatedDuration: Duration(milliseconds: buffer.length * charsPerMs),
      ));
    }

    return chunks;
  }
}
