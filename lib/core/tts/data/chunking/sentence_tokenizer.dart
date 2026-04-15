import '../engines/tts_engine.dart';

/// A rich token produced by [SentenceTokenizer].
class SentenceMeta {
  const SentenceMeta({
    required this.text,
    required this.tone,
    required this.language,
    required this.flatIndex,
    required this.paragraphIndex,
    required this.sentenceIndexInParagraph,
    required this.isFirstInParagraph,
    required this.isLastInParagraph,
    required this.wordCount,
    required this.estimatedDurationMs,
  });

  final String text;
  final SentenceTone tone;
  final ArticleLanguage language;

  /// Flat position across the whole article (for chunk mapping)
  final int flatIndex;
  final int paragraphIndex;
  final int sentenceIndexInParagraph;
  final bool isFirstInParagraph;
  final bool isLastInParagraph;
  final int wordCount;
  final int estimatedDurationMs;
}

class SentenceTokenizer {
  SentenceTokenizer._();

  // ─── Average ms-per-character heuristics ─────────────────────────────────
  // Bengali characters are phonetically richer, so they render slightly slower.
  static const int _enMsPerChar = 55;
  static const int _bnMsPerChar = 72;

  // ─── Abbreviations that must NOT trigger a sentence split ────────────────
  static final RegExp _enAbbreviations = RegExp(
    r'\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|St|vs|etc|e\.g|i\.e|approx|dept|est|no|vol|fig|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec|Inc|Ltd|Gov|Rep|Sen|Gen|Capt|Col|U\.S|U\.K|U\.N)\.',
    caseSensitive: false,
  );

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Tokenizes [text] into a list of [SentenceMeta] objects with full
  /// structural and prosodic metadata attached.
  ///
  /// [language] defaults to [ArticleLanguage.auto].
  static List<SentenceMeta> tokenize(
    String text, {
    ArticleLanguage language = ArticleLanguage.auto,
  }) {
    if (text.trim().isEmpty) return [];

    final lang = language == ArticleLanguage.auto
        ? _detectLanguage(text)
        : language;

    final paragraphs = _splitParagraphs(text);
    final result = <SentenceMeta>[];
    var flatIndex = 0;

    for (var pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final sentences = lang == ArticleLanguage.bengali
          ? _splitBengali(paragraphs[pIdx])
          : _splitEnglish(paragraphs[pIdx]);

      final total = sentences.length;

      for (var sIdx = 0; sIdx < total; sIdx++) {
        final cleaned = sentences[sIdx].trim();
        if (cleaned.isEmpty) continue;

        final wordCount = _countWords(cleaned, lang);
        final durationMs = cleaned.length *
            (lang == ArticleLanguage.bengali ? _bnMsPerChar : _enMsPerChar);

        result.add(SentenceMeta(
          text: cleaned,
          tone: _detectTone(cleaned, lang),
          language: lang,
          flatIndex: flatIndex++,
          paragraphIndex: pIdx,
          sentenceIndexInParagraph: sIdx,
          isFirstInParagraph: sIdx == 0,
          isLastInParagraph: sIdx == total - 1,
          wordCount: wordCount,
          estimatedDurationMs: durationMs,
        ));
      }
    }

    return result;
  }

  /// Convenience: returns plain strings, preserving the previous API contract
  /// so callers that only need text strings can still use a one-liner.
  static List<String> tokenizeToStrings(
    String text, {
    ArticleLanguage language = ArticleLanguage.auto,
  }) =>
      tokenize(text, language: language).map((m) => m.text).toList();

  // ─── Paragraph splitting ─────────────────────────────────────────────────

  static List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n{2,}|\r\n\r\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  // ─── Sentence splitting ───────────────────────────────────────────────────

  static List<String> _splitBengali(String paragraph) {
    // Bengali terminators: ।  ?  !
    // Added quote capture to avoid splitting dialog incorrectly.
    final raw = RegExp(r'[^।?!]+[।?!]+(?:["”\u0027\u2019\u201D]{1,2})?').allMatches(paragraph);
    final results =
        raw.map((m) => m.group(0)!.trim()).where((s) => s.length > 2).toList();

    // Capture trailing text without terminator
    final consumed = raw.fold(0, (p, m) => m.end);
    final tail = paragraph.substring(consumed).trim();
    if (tail.length > 2) results.add(tail);

    return results.isEmpty ? [paragraph] : results;
  }

  static List<String> _splitEnglish(String paragraph) {
    // Protect known abbreviations by replacing their period with a placeholder
    final protected = paragraph.replaceAllMapped(
      _enAbbreviations,
      (m) => m.group(0)!.replaceAll('.', '\x01'),
    );

    final raw = RegExp(r'[^.?!]+[.?!]+(?:["”\u0027\u2019\u201D]{1,2})?(?:\s|$)', dotAll: true)
        .allMatches(protected);
    final results = raw
        .map((m) => m.group(0)!.replaceAll('\x01', '.').trim())
        .where((s) => s.length > 2)
        .toList();

    final consumed = raw.fold(0, (p, m) => m.end);
    final tail =
        protected.substring(consumed).replaceAll('\x01', '.').trim();
    if (tail.length > 2) results.add(tail);

    return results.isEmpty ? [paragraph] : results;
  }

  // ─── Tone detection ───────────────────────────────────────────────────────

  static SentenceTone _detectTone(String sentence, ArticleLanguage lang) {
    final s = sentence.trim();
    if (s.isEmpty) return SentenceTone.statement;

    final isQuote = s.startsWith('"') || s.startsWith('“') || s.startsWith('\u0027');
    final coreStr = isQuote ? s.replaceAll(RegExp(r'["”\u0027\u2019\u201D]'), '').trim() : s;
    final lastChar = coreStr.isNotEmpty ? coreStr[coreStr.length - 1] : s[s.length - 1];

    // ── Bengali Grammar: Interrogative Word Detection ────────────────────────
    bool isBengaliQuestion = false;
    if (lang == ArticleLanguage.bengali) {
      // Common Bengali interrogative words
      final interrogatives = RegExp(
        r'(কি|কী|কেন|কীভাবে|কিভাবে|কখন|কোথায়|কোথা|কবে|কোন|কার|কাকে|কয়|কত)',
      );
      if (interrogatives.hasMatch(s)) {
        isBengaliQuestion = true;
      }
    }

    if (lastChar == '?' || isBengaliQuestion) {
      return isQuote ? SentenceTone.exclamatoryQuestion : SentenceTone.question;
    }
    if (lastChar == '!') return SentenceTone.exclamation;
    
    if (isQuote) {
       return SentenceTone.quote;
    }

    // ── Bengali Grammar: Emphasis Detection ──────────────────────────────────
    if (lang == ArticleLanguage.bengali) {
      // Particles like '-ই' (emphasis) or '-ও' (also/even)
      if (s.contains('ই ') || s.endsWith('ই') || s.contains('ও ') || s.endsWith('ও')) {
        // We'll treat emphasized sentences as slightly more "exclamatory" 
        // to boost pitch/rate later in the engine.
        // For now, if it's not a quote, let's keep it as statement but 
        // the engine can check the text itself or we can add a new tone.
        // I'll stick to statement but the engine logic already checks text.
      }
    }

    if (RegExp(r'(,\s*\S+){2,}').hasMatch(s)) return SentenceTone.listing;

    // Parenthetical / aside
    if (s.startsWith('(') ||
        s.startsWith('\u2014') ||
        s.startsWith('\u2013') ||
        s.startsWith('–')) {
      return SentenceTone.parenthetical;
    }

    if (s.contains('"') || s.contains('“')) {
       return SentenceTone.dialogue;
    }

    return SentenceTone.statement;
  }

  // ─── Language detection ───────────────────────────────────────────────────

  static ArticleLanguage _detectLanguage(String text) {
    final bengaliCount = RegExp(r'[\u0980-\u09FF]').allMatches(text).length;
    final total = text
        .replaceAll(
            RegExp(r'[^\u0980-\u09FF\u0041-\u007A\u0041-\u005A]'), '')
        .length;
    if (total == 0) return ArticleLanguage.english;
    return bengaliCount / total > 0.25
        ? ArticleLanguage.bengali
        : ArticleLanguage.english;
  }

  // ─── Utilities ────────────────────────────────────────────────────────────

  static int _countWords(String text, ArticleLanguage lang) {
    // Bengali words are whitespace-delimited just like English
    return text.trim().split(RegExp(r'\s+')).length;
  }
}