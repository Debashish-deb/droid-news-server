import '../models/speech_chunk.dart';

class TtsChunker {
  static const int _maxChunkChars = 250;

  /// Splits text into optimized speech chunks
  static List<SpeechChunk> chunk(String text, {String language = 'en'}) {
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return [];

    final List<String> sentences = _splitIntoSentences(cleanText);
    final List<SpeechChunk> chunks = [];
    
    int id = 0;
    int currentIndex = 0;
    StringBuffer buffer = StringBuffer();
    int chunkStartIndex = 0;

    for (final sentence in sentences) {
      if (buffer.length + sentence.length + 1 <= _maxChunkChars) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(sentence);
      } else {
        // Push current buffer
        if (buffer.isNotEmpty) {
          final content = buffer.toString();
          chunks.add(SpeechChunk(
            id: id++,
            text: content,
            startIndex: chunkStartIndex,
            endIndex: chunkStartIndex + content.length,
            language: language,
          ));
          chunkStartIndex += content.length + 1; // +1 for space
          buffer.clear();
        }

        // Check if sentence itself is huge
        if (sentence.length > _maxChunkChars) {
          final subChunks = _hardWrap(sentence, _maxChunkChars);
          for (final sub in subChunks) {
             chunks.add(SpeechChunk(
              id: id++,
              text: sub,
              startIndex: chunkStartIndex,
              endIndex: chunkStartIndex + sub.length,
              language: language,
            ));
            chunkStartIndex += sub.length + 1;
          }
        } else {
          buffer.write(sentence);
        }
      }
    }

    // Push remaining buffer
    if (buffer.isNotEmpty) {
      final content = buffer.toString();
      chunks.add(SpeechChunk(
        id: id++,
        text: content,
        startIndex: chunkStartIndex,
        endIndex: chunkStartIndex + content.length,
        language: language,
      ));
    }

    return chunks;
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .replaceAll(RegExp(r'\[\d+\]'), '') // Remove citations like [1]
        .trim();
  }

  static List<String> _splitIntoSentences(String text) {
    // Regex for sentence ending punctuation (. ? !) followed by space or end of string
    // Handles obscure abbreviations manually if needed, but basic regex suffices for MVP
    final RegExp sentenceBreak = RegExp(r'(?<=[.!?])\s+(?=[A-Z])|(?<=[.!?])$');
    return text.split(sentenceBreak).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  static List<String> _hardWrap(String text, int limit) {
    List<String> result = [];
    for (int i = 0; i < text.length; i += limit) {
      int end = (i + limit < text.length) ? i + limit : text.length;
      result.add(text.substring(i, end).trim());
    }
    return result;
  }
}
