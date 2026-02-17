import '../../domain/entities/tts_chunk.dart';
import 'sentence_tokenizer.dart';

class ChunkScheduler {
  static const int maxChunkLength = 280; // Optimal length for many TTS engines
  static const int charsPerMs = 40; // Rough heuristic for duration estimation

  static List<TtsChunk> buildChunks(
    String text, {
    String? title,
    String? author,
    String? imageSource,
    String language = 'en',
  }) {
    if (text.isEmpty) return [];
    
    final introPhrase = language.startsWith('bn') ? 'বিস্তারিত খবরে আসছি' : 'Moving on to detailed news';
    final titleLabel = language.startsWith('bn') ? 'শিরোনাম: ' : 'Title: ';
    final reporterLabel = language.startsWith('bn') ? 'প্রতিবেদক: ' : 'Reporter: ';
    final courtesyLabel = language.startsWith('bn') ? 'ছবি সৌজন্যে: ' : 'Photo courtesy: ';
    final metadataWarning = language.startsWith('bn') ? 'সতর্কবার্তা, এটি সংবাদ সংশ্লিষ্ট তথ্য মাত্র: ' : 'Notice, the following is metadata only: ';

    final StringBuffer fullTextBuffer = StringBuffer();
    
    // 1. Structured Title
    if (title != null && title.isNotEmpty) {
      fullTextBuffer.write('$titleLabel $title. ');
      fullTextBuffer.write('$introPhrase. ');
    }
    
    // 2. Metadata with Warning Labels
    bool hasMetadata = (author != null && author.isNotEmpty) || (imageSource != null && imageSource.isNotEmpty);
    if (hasMetadata) {
      fullTextBuffer.write('$metadataWarning. ');
      if (author != null && author.isNotEmpty) {
        fullTextBuffer.write('$reporterLabel $author. ');
      }
      if (imageSource != null && imageSource.isNotEmpty) {
        fullTextBuffer.write('$courtesyLabel $imageSource. ');
      }
      fullTextBuffer.write('. '); 
    }
    
    fullTextBuffer.write(text);
    
    final sentences = SentenceTokenizer.tokenize(fullTextBuffer.toString());
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
