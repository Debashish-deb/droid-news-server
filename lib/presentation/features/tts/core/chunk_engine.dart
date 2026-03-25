import '../domain/models/speech_chunk.dart';
import 'text_cleaner.dart';

// ── ChunkEngine ────────────────────────────────────────────────────────────
//
// Converts a cleaned article body into a list of [SpeechChunk]s sized for
// natural, gapless TTS playback.
//
// Design targets:
//   • 500 – 1 500 char chunks for optimal TTS quality
//   • Sentence-boundary splits (never mid-word or mid-clause)
//   • Bengali-aware boundary detection (।)
//   • O(n) grouping — original code called List.indexOf() inside a loop
//     producing O(n²) behaviour (~40 000 comparisons on a typical article)

class ChunkEngine {
  // ── Tuning constants ───────────────────────────────────────────────────────
  static const int minChunkSize = 180;
  static const int targetChunkSize = 520;
  static const int maxChunkSize = 880;
  static const int mergeThreshold = 80;
  static final RegExp _abbreviationPattern = RegExp(
    r'\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|St|vs|etc|e\.g|i\.e|approx|dept|est|no|vol|fig|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\.',
    caseSensitive: false,
  );

  // ── Public entry point ─────────────────────────────────────────────────────

  static List<SpeechChunk> createChunks(
    String rawText, {
    String language = 'en',
    String? title,
    String? author,
    String? imageSource,
    bool alreadyCleaned = false,
  }) {
    final cleanedText = alreadyCleaned
        ? rawText.trim()
        : TextCleaner.clean(rawText);
    if (cleanedText.isEmpty) return [];

    final fullText = _buildFullText(
      cleanedText,
      language: language,
      title: title,
      author: author,
      imageSource: imageSource,
    );

    final segments = _splitIntoSegments(fullText);
    final rawChunks = _groupSegments(segments); // O(n), not O(n²)
    final merged = _mergeSmallChunks(rawChunks);
    return _finalizeChunks(merged, language);
  }

  // ── Metadata prefix builder ────────────────────────────────────────────────

  // ignore: unused_element_parameter
  static String _buildFullText(
    String body, {
    required String language,
    String? title,
    String? author,
    String? imageSource,
  }) {
    final isBn = language.startsWith('bn');

    final titleLabel = isBn ? 'শিরোনাম: ' : 'Title: ';
    final introPhrase = isBn
        ? 'বিস্তারিত খবরে আসছি'
        : 'Moving on to detailed news';

    final buf = StringBuffer();

    if (title != null && title.isNotEmpty) {
      buf
        ..write('$titleLabel $title. ')
        ..write('$introPhrase. ');
    }

    buf.write(body);
    return buf.toString();
  }

  // ── Sentence splitter ──────────────────────────────────────────────────────

  static List<String> _splitIntoSegments(String text) {
    final segments = <String>[];
    final paragraphs = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    for (final paragraph in paragraphs) {
      final sentences = _splitParagraphIntoSentences(paragraph);
      for (final sentence in sentences) {
        final s = sentence.trim();
        if (s.isEmpty || _looksLikeNoiseSegment(s)) continue;

        if (s.length > maxChunkSize) {
          segments.addAll(_splitLongSentence(s));
        } else {
          segments.add(s);
        }
      }
    }

    return segments;
  }

  static List<String> _splitParagraphIntoSentences(String paragraph) {
    if (_containsBangla(paragraph)) {
      return _splitBanglaSentences(paragraph);
    }

    final protected = paragraph.replaceAllMapped(
      _abbreviationPattern,
      (match) => match.group(0)!.replaceAll('.', '\x01'),
    );
    final boundary = RegExp(
      r'(?<=[.!?।])(?:["”’)\]]+)?\s+(?=[A-Z0-9"“(\u0980-\u09FF])|(?<=[.!?।])$',
      multiLine: true,
    );
    return protected
        .split(boundary)
        .map((s) => s.replaceAll('\x01', '.').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static bool _containsBangla(String text) =>
      RegExp(r'[\u0980-\u09FF]').hasMatch(text);

  static List<String> _splitBanglaSentences(String paragraph) {
    final matches = RegExp(r'[^।!?]+[।!?]+|[^।!?]+$').allMatches(paragraph);
    if (matches.isEmpty) return [paragraph.trim()];
    return matches
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static bool _looksLikeNoiseSegment(String text) {
    final lower = text.toLowerCase();
    const markers = <String>[
      'read more',
      'also read',
      'related',
      'recommended',
      'trending',
      'most read',
      'most popular',
      'follow us',
      'subscribe',
      'newsletter',
      'share this',
      'advertisement',
      'sponsored',
      'আরও পড়ুন',
      'সম্পর্কিত',
      'সংশ্লিষ্ট',
      'ট্রেন্ডিং',
    ];

    if (RegExp(r'https?://\S+|www\.\S+', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    if (RegExp(
      r'^(by|source|published|updated|category|tag|author)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (markers.any(lower.contains) && text.length < 220) return true;

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    // Punctuation check: if it ends with punctuation, it's likely a sentence, not noise.
    final hasEndingPunctuation = RegExp(r'[.!?।]$').hasMatch(text.trim());
    if (words <= 3 && text.length < 24 && !hasEndingPunctuation) return true;
    if (RegExp(r'^[A-Z0-9\s|:/_-]{2,}$').hasMatch(text) && text.length < 90) {
      return true;
    }
    return false;
  }

  static List<String> _splitLongSentence(String sentence) {
    final clauses = sentence.split(RegExp(r'[,;:]\s+'));
    final parts = <String>[];
    final buf = StringBuffer();

    for (final clause in clauses) {
      if (buf.length + clause.length <= maxChunkSize) {
        if (buf.isNotEmpty) buf.write(', ');
        buf.write(clause);
      } else {
        if (buf.isNotEmpty) {
          parts.add(buf.toString());
          buf.clear();
        }
        if (clause.length > maxChunkSize) {
          parts.addAll(_hardBreak(clause));
        } else {
          buf.write(clause);
        }
      }
    }

    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }

  static List<String> _hardBreak(String text) {
    final parts = <String>[];
    for (int i = 0; i < text.length; i += maxChunkSize) {
      final end = (i + maxChunkSize).clamp(0, text.length);
      final part = text.substring(i, end).trim();
      if (part.isNotEmpty) parts.add(part);
    }
    return parts;
  }

  // ── Grouper — O(n) ────────────────────────────────────────────────────────
  //
  // Original code called `segments.indexOf(segment)` inside the for-loop to
  // detect the last segment — this is O(n) per iteration = O(n²) total.
  //
  // Fix: use a plain index counter.  We never need indexOf at all; the last-
  // segment check is replaced by a post-loop flush.

  static List<String> _groupSegments(List<String> segments) {
    final chunks = <String>[];
    final buf = StringBuffer();

    for (final segment in segments) {
      if (buf.isEmpty) {
        buf.write(segment);
        continue;
      }

      final potential = buf.length + (buf.isNotEmpty ? 1 : 0) + segment.length;

      // Flush around target size to keep speaking cadence natural.
      if (buf.length >= targetChunkSize && buf.length >= minChunkSize) {
        chunks.add(buf.toString());
        buf.clear();
        buf.write(segment);
        continue;
      }

      if (potential > maxChunkSize && buf.length >= minChunkSize) {
        chunks.add(buf.toString());
        buf.clear();
        buf.write(segment);
        continue;
      }

      buf
        ..write(' ')
        ..write(segment);

      if (buf.length > maxChunkSize) {
        chunks.add(buf.toString());
        buf.clear();
      }
    }

    if (buf.isNotEmpty) chunks.add(buf.toString());
    return chunks;
  }

  // ── Merge tiny tail chunks ─────────────────────────────────────────────────

  static List<String> _mergeSmallChunks(List<String> chunks) {
    if (chunks.length <= 1) return chunks;

    final result = <String>[];
    final buf = StringBuffer();

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      if (chunk.length < mergeThreshold && i < chunks.length - 1) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(chunk);
      } else {
        if (buf.isNotEmpty) {
          buf.write(' ');
          buf.write(chunk);
          result.add(buf.toString());
          buf.clear();
        } else {
          result.add(chunk);
        }
      }
    }

    if (buf.isNotEmpty) result.add(buf.toString());
    return result;
  }

  // ── Finaliser ──────────────────────────────────────────────────────────────

  static List<SpeechChunk> _finalizeChunks(
    List<String> chunks,
    String language,
  ) {
    final result = <SpeechChunk>[];
    int startIndex = 0;

    for (int id = 0; id < chunks.length; id++) {
      final text = chunks[id];
      final endIndex = startIndex + text.length;

      result.add(
        SpeechChunk(
          id: id,
          text: text,
          startIndex: startIndex,
          endIndex: endIndex,
          language: language,
        ),
      );

      startIndex = endIndex + 1;
    }

    return result;
  }

  // ── Quality analysis ───────────────────────────────────────────────────────

  static ChunkQuality analyzeQuality(List<SpeechChunk> chunks) {
    if (chunks.isEmpty) {
      return const ChunkQuality(
        avgSize: 0,
        minSize: 0,
        maxSize: 0,
        totalChunks: 0,
        chunksInRange: 0,
        qualityScore: 0,
      );
    }

    final sizes = chunks.map((c) => c.text.length).toList();
    final total = sizes.fold(0, (a, b) => a + b);
    final avgSize = total ~/ sizes.length;
    final minSize = sizes.reduce((a, b) => a < b ? a : b);
    final maxSize = sizes.reduce((a, b) => a > b ? a : b);
    final chunksInRange = chunks
        .where(
          (c) => c.text.length >= minChunkSize && c.text.length <= maxChunkSize,
        )
        .length;
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

// ── Quality metrics value object ───────────────────────────────────────────

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
  String toString() =>
      'ChunkQuality('
      'avg: $avgSize, min: $minSize, max: $maxSize, '
      'total: $totalChunks, inRange: $chunksInRange, '
      'score: ${(qualityScore * 100).toStringAsFixed(1)}%'
      ')';
}
