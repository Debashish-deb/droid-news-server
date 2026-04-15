import '../../domain/entities/tts_chunk.dart';
import '../engines/tts_engine.dart';
import 'sentence_tokenizer.dart';

/// Builds a flat, UI-ready list of [TtsChunk]s from article text.
///
/// **Role shift**: [ChunkScheduler] is now the *display* layer — it produces
/// one [TtsChunk] per logical sentence so the UI can highlight sentences in
/// real time.  Actual humanized speech is driven by [TtsEngine.speakArticle];
/// the chunk list is only used for UI state mapping.
class ChunkScheduler {
  ChunkScheduler._();

  /// Characters-per-millisecond heuristics (per language)
  static const int _enMsPerChar = 55;
  static const int _bnMsPerChar = 72;

  /// Builds a UI chunk list from [text].
  ///
  /// One [TtsChunk] is emitted per *sentence* (not per arbitrary character
  /// window), so that the playback runtime can map engine `sentenceStart`
  /// events directly to chunk indices without any secondary alignment step.
  ///
  /// [title] and [author] are prepended as dedicated chunks when provided so
  /// the UI can highlight them separately.
  static List<TtsChunk> buildChunks(
    String text, {
    String? title,
    String? author,
    String? imageSource, // reserved for future image-caption TTS
    String language = 'en',
  }) {
    if (text.trim().isEmpty) return [];

    final lang = language.startsWith('bn')
        ? ArticleLanguage.bengali
        : ArticleLanguage.english;

    final chunks = <TtsChunk>[];
    var index = 0;

    // ── Preamble chunks ────────────────────────────────────────────────────
    if (title != null && title.trim().isNotEmpty) {
      final label = lang == ArticleLanguage.bengali ? 'শিরোনাম: ' : 'Title: ';
      final titleText = '$label${title.trim()}';
      chunks.add(
        TtsChunk(
          index: index++,
          text: titleText,
          estimatedDuration: _duration(titleText, lang),
          isTitleChunk: true,
          paragraphIndex: -1,
          sentenceIndexInParagraph: -1,
        ),
      );
    }

    if (author != null && author.trim().isNotEmpty) {
      final label = lang == ArticleLanguage.bengali ? 'লেখক: ' : 'By ';
      final authorText = '$label${author.trim()}';
      chunks.add(
        TtsChunk(
          index: index++,
          text: authorText,
          estimatedDuration: _duration(authorText, lang),
          isAuthorChunk: true,
          paragraphIndex: -1,
          sentenceIndexInParagraph: -1,
        ),
      );
    }

    // ── Body chunks (one per sentence) ────────────────────────────────────
    final sentences = SentenceTokenizer.tokenize(text, language: lang);

    for (final meta in sentences) {
      chunks.add(
        TtsChunk(
          index: index++,
          text: meta.text,
          estimatedDuration: Duration(milliseconds: meta.estimatedDurationMs),
          paragraphIndex: meta.paragraphIndex,
          sentenceIndexInParagraph: meta.sentenceIndexInParagraph,
        ),
      );
    }

    return chunks;
  }

  /// Returns the full article text that the engine should receive, including
  /// any title/author preamble injected in the reading voice's natural style.
  ///
  /// Keep this in sync with [buildChunks] preamble logic so chunk indices
  /// always match what the engine speaks.
  static String buildSpeakableText(
    String text, {
    String? title,
    String? author,
    String language = 'en',
  }) {
    final lang = language.startsWith('bn')
        ? ArticleLanguage.bengali
        : ArticleLanguage.english;

    final buf = StringBuffer();

    if (title != null && title.trim().isNotEmpty) {
      if (lang == ArticleLanguage.bengali) {
        buf.writeln('শিরোনাম: ${title.trim()}।');
        buf.writeln('বিস্তারিত খবরে আসছি।');
      } else {
        buf.writeln('Title: ${title.trim()}.');
        buf.writeln('Moving on to the full story.');
      }
    }

    if (author != null && author.trim().isNotEmpty) {
      final credit = lang == ArticleLanguage.bengali
          ? 'লেখক: ${author.trim()}।'
          : 'Written by ${author.trim()}.';
      buf.writeln(credit);
    }

    buf.write(text.trim());
    return buf.toString();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static Duration _duration(String text, ArticleLanguage lang) {
    final msPerChar = lang == ArticleLanguage.bengali
        ? _bnMsPerChar
        : _enMsPerChar;
    return Duration(milliseconds: text.length * msPerChar);
  }
}
