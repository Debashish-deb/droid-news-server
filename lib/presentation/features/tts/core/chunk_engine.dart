import '../domain/models/speech_chunk.dart';
import 'text_cleaner.dart';

// Industrial-grade chunk engine with advanced boundary detection
// 
// Produces natural speech chunks that:
// - Respect sentence boundaries
// - Merge small chunks for fluency
// - Avoid breaking mid-sentence
// - Handle lists, quotes, and special content
// - Target 500-1500 character chunks
class ChunkEngine {
  static const int minChunkSize = 500;
  static const int targetChunkSize = 1000;
  static const int maxChunkSize = 1500;
  
  static const int mergeThreshold = 100;
  
  static List<SpeechChunk> createChunks(
    String rawText, {
    String language = 'en',
    String? title,
    String? author,
    String? imageSource,
  }) {
    
    final cleanedText = TextCleaner.clean(rawText);
    if (cleanedText.isEmpty) return [];
    
    final introPhrase = language == 'bn' ? 'বিস্তারিত খবরে আসছি' : 'Moving on to detailed news';
    final titleLabel = language == 'bn' ? 'শিরোনাম: ' : 'Title: ';
    final reporterLabel = language == 'bn' ? 'প্রতিবেদক: ' : 'Reporter: ';
    final courtesyLabel = language == 'bn' ? 'ছবি সৌজন্যে: ' : 'Photo courtesy: ';
    final metadataWarning = language == 'bn' ? 'সতর্কবার্তা, এটি সংবাদ সংশ্লিষ্ট তথ্য মাত্র: ' : 'Notice, the following is metadata only: ';
    
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
      fullTextBuffer.write('. '); // Small pause after metadata
    }
    
    // 3. Main News Content
    fullTextBuffer.write(cleanedText);
    
    final fullText = fullTextBuffer.toString();
    
    final segments = _splitIntoSegments(fullText);
    
    final rawChunks = _groupSegments(segments, language);
    
    final mergedChunks = _mergeSmallChunks(rawChunks);
    
    return _finalizeChunks(mergedChunks, language);
  }
  
 
  static List<String> _splitIntoSegments(String text) {
    final segments = <String>[];
    final sentencePattern = RegExp(
      r'(?<=[.!?।])\s+(?=[A-Z\u0980-\u09FF])|(?<=[.!?।])$',
      multiLine: true,
    );
    
    final sentences = text.split(sentencePattern);
    
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;
      
      if (trimmed.length > maxChunkSize) {
        segments.addAll(_splitLongSentence(trimmed));
      } else {
        segments.add(trimmed);
      }
    }
    
    return segments;
  }
  
  static List<String> _splitLongSentence(String sentence) {
    final parts = <String>[];
    
    final subSentencePattern = RegExp(r'[,;:]\s+');
    final clauses = sentence.split(subSentencePattern);
    
    final StringBuffer buffer = StringBuffer();
    
    for (final clause in clauses) {
      if (buffer.length + clause.length <= maxChunkSize) {
        if (buffer.isNotEmpty) buffer.write(', ');
        buffer.write(clause);
      } else {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
        
        if (clause.length > maxChunkSize) {
          parts.addAll(_hardBreak(clause));
        } else {
          buffer.write(clause);
        }
      }
    }
    
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    
    return parts;
  }
  
  static List<String> _hardBreak(String text) {
    final parts = <String>[];
    
    for (int i = 0; i < text.length; i += maxChunkSize) {
      final end = (i + maxChunkSize).clamp(0, text.length);
      parts.add(text.substring(i, end).trim());
    }
    
    return parts;
  }
  
  static List<String> _groupSegments(List<String> segments, String language) {
    final chunks = <String>[];
    final StringBuffer buffer = StringBuffer();
    
    for (final segment in segments) {
      final potentialLength = buffer.length + segment.length + 1;
      
      if (potentialLength <= maxChunkSize) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(segment);
      } else {
        if (buffer.length >= minChunkSize || segments.indexOf(segment) == segments.length - 1) {
          chunks.add(buffer.toString());
          buffer.clear();
          buffer.write(segment);
        } else {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(segment);
        }
      }
    }
    
 
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }
    
    return chunks;
  }
  
  static List<String> _mergeSmallChunks(List<String> chunks) {
    if (chunks.length <= 1) return chunks;
    
    final merged = <String>[];
    final StringBuffer buffer = StringBuffer();
    
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      
      if (chunk.length < mergeThreshold && i < chunks.length - 1) {
        buffer.write(chunk);
        buffer.write(' ');
      } else {
        if (buffer.isNotEmpty) {
          buffer.write(chunk);
          merged.add(buffer.toString());
          buffer.clear();
        } else {
          merged.add(chunk);
        }
      }
    }
    
    if (buffer.isNotEmpty) {
      merged.add(buffer.toString());
    }
    
    return merged;
  }
  
  static List<SpeechChunk> _finalizeChunks(
    List<String> chunks,
    String language,
  ) {
    final result = <SpeechChunk>[];
    int startIndex = 0;
    
    for (int id = 0; id < chunks.length; id++) {
      final text = chunks[id];
      final endIndex = startIndex + text.length;
      
      result.add(SpeechChunk(
        id: id,
        text: text,
        startIndex: startIndex,
        endIndex: endIndex,
        language: language,
      ));
      
      startIndex = endIndex + 1;
    }
    
    return result;
  }
  
  static ChunkQuality analyzeQuality(List<SpeechChunk> chunks) {
    if (chunks.isEmpty) {
      return const ChunkQuality(
        avgSize: 0,
        minSize: 0,
        maxSize: 0,
        totalChunks: 0,
        chunksInRange: 0,
        qualityScore: 0.0,
      );
    }
    
    final sizes = chunks.map((c) => c.text.length).toList();
    final avgSize = sizes.reduce((a, b) => a + b) ~/ sizes.length;
    final minSize = sizes.reduce((a, b) => a < b ? a : b);
    final maxSize = sizes.reduce((a, b) => a > b ? a : b);
    final chunksInRange = chunks.where(
      (c) => c.text.length >= minChunkSize && c.text.length <= maxChunkSize,
    ).length;
    
    final qualityScore = chunksInRange / chunks.length;
    
    return ChunkQuality(
      avgSize: avgSize,
      minSize: minSize,
      maxSize: maxSize,
      totalChunks: chunks.length,
      chunksInRange: chunksInRange,
      qualityScore: qualityScore,
    );
  }
}

// Chunk quality metrics
class ChunkQuality { 
  
  const ChunkQuality({
    required this.avgSize,
    required this.minSize,
    required this.maxSize,
    required this.totalChunks,
    required this.chunksInRange,
    required this.qualityScore,
  });
  final int avgSize;
  final int minSize;
  final int maxSize;
  final int totalChunks;
  final int chunksInRange;
  final double qualityScore;
  
  @override
  String toString() {
    return 'ChunkQuality('
           'avg: $avgSize, min: $minSize, max: $maxSize, '
           'total: $totalChunks, inRange: $chunksInRange, '
           'score: ${(qualityScore * 100).toStringAsFixed(1)}%'
           ')';
  }
}
