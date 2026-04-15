import 'dart:math' as math;

/// ─────────────────────────────────────────────────────────────────────────────
/// AAA-grade Bilingual Reading Time Estimator
/// Calibrated for Bangladeshi readers of বাংলা & English content
///
/// Features:
///  1. Separate Bangla vs English WPM profiles (Bangla reads slower)
///  2. Script-aware word counting (Bengali Unicode segmentation)
///  3. Complexity modelling: sentence length, technical vocabulary, numerics
///  4. Reader speed profiles: শিশু (child), সাধারণ (normal), দ্রুত (fast)
///  5. Bangla-specific complexity signals (compound words, formal vocabulary)
///  6. Content type detection (news, opinion, technical) → adjusted WPM
///  7. Formatted output in both বাংলা and English
/// ─────────────────────────────────────────────────────────────────────────────
class ReadingTimeEstimator {
  ReadingTimeEstimator._();
  static final ReadingTimeEstimator instance = ReadingTimeEstimator._();

  // ── Reading speed constants (words per minute) ─────────────────────────────
  // Research baseline: Average adult English reader ≈ 238 WPM
  // Bengali script is more complex — studies suggest ~160–180 WPM for native readers
  static const _englishWpm = <ReaderSpeed, double>{
    ReaderSpeed.child: 130,
    ReaderSpeed.slow: 170,
    ReaderSpeed.normal: 238,
    ReaderSpeed.fast: 300,
    ReaderSpeed.skimmer: 450,
  };

  static const _banglaWpm = <ReaderSpeed, double>{
    ReaderSpeed.child: 80,
    ReaderSpeed.slow: 110,
    ReaderSpeed.normal: 165,
    ReaderSpeed.fast: 210,
    ReaderSpeed.skimmer: 300,
  };

  // ── Bangla technical/formal vocabulary (increases complexity) ──────────────
  static const _banglaTechnicalVocab = {
    'অর্থনীতি',
    'রাজনীতি',
    'কূটনীতি',
    'সংবিধান',
    'মন্ত্রণালয়',
    'প্রতিষ্ঠান',
    'উন্নয়ন',
    'পরিকল্পনা',
    'বাস্তবায়ন',
    'প্রকল্প',
    'আইনশৃঙ্খলা',
    'প্রশাসনিক',
    'ব্যবস্থাপনা',
    'কর্তৃপক্ষ',
    'সংগঠন',
    'বিনিয়োগকারী',
    'মূল্যস্ফীতি',
    'প্রবৃদ্ধি',
    'রপ্তানিমুখী',
    'পরিবেশ',
  };

  // ── English technical indicators ───────────────────────────────────────────
  static const _englishTechnicalIndicators = [
    'pursuant',
    'thereof',
    'whereupon',
    'notwithstanding',
    'henceforth',
    'legislation',
    'jurisdiction',
    'infrastructure',
    'macroeconomic',
    'parliamentary',
    'constitutional',
    'diplomatic',
    'bilateral',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Full reading time analysis with breakdown
  ReadingTimeResult estimate({
    required String content,
    String? title,
    bool? isBangla,
    ReaderSpeed readerSpeed = ReaderSpeed.normal,
    ContentType contentType = ContentType.news,
  }) {
    final fullText = [title, content].whereType<String>().join(' ');

    // Auto-detect language if not specified
    final banglaDetected = isBangla ?? _isBangla(fullText);

    final analysis = _analyzeText(fullText, isBangla: banglaDetected);
    final wpmBase = banglaDetected
        ? _banglaWpm[readerSpeed]!
        : _englishWpm[readerSpeed]!;

    // Content-type speed adjustment
    final contentMultiplier = _contentTypeMultiplier(contentType);

    // Complexity multiplier (1.0 = normal, up to 1.6 = very complex)
    final complexityMultiplier = _complexityMultiplier(
      analysis,
      isBangla: banglaDetected,
    );

    // Effective WPM
    final effectiveWpm = wpmBase * contentMultiplier / complexityMultiplier;

    // Reading time in minutes
    final rawMinutes = analysis.wordCount / effectiveWpm;
    final adjustedMinutes = math.max(0.5, rawMinutes);

    // Image viewing time (avg 12 sec per image per Nielsen)
    final imageViewingMinutes = analysis.imageCount * (12 / 60);
    final totalMinutes = adjustedMinutes + imageViewingMinutes;

    return ReadingTimeResult(
      minutes: totalMinutes,
      wordCount: analysis.wordCount,
      characterCount: analysis.charCount,
      sentenceCount: analysis.sentenceCount,
      paragraphCount: analysis.paragraphCount,
      imageCount: analysis.imageCount,
      effectiveWpm: effectiveWpm,
      complexityScore: analysis.complexityScore,
      isBangla: banglaDetected,
      readerSpeed: readerSpeed,
      contentType: contentType,
    );
  }

  /// Convenience: get a single formatted string estimate
  String estimateFormatted({
    required String content,
    String? title,
    bool? isBangla,
    ReaderSpeed readerSpeed = ReaderSpeed.normal,
    bool inBangla = true,
  }) {
    final result = estimate(
      content: content,
      title: title,
      isBangla: isBangla,
      readerSpeed: readerSpeed,
    );
    return inBangla ? result.formattedBn : result.formattedEn;
  }

  /// Get all speed variants at once
  Map<ReaderSpeed, ReadingTimeResult> getAllSpeedEstimates({
    required String content,
    String? title,
    bool? isBangla,
  }) {
    return {
      for (final speed in ReaderSpeed.values)
        speed: estimate(
          content: content,
          title: title,
          isBangla: isBangla,
          readerSpeed: speed,
        ),
    };
  }

  // ── Text analysis ──────────────────────────────────────────────────────────

  _TextAnalysis _analyzeText(String text, {required bool isBangla}) {
    final wordCount = isBangla ? _countBanglaWords(text) : _countWords(text);
    final charCount = text.replaceAll(RegExp(r'\s'), '').length;
    final sentenceCount = _countSentences(text, isBangla: isBangla);
    final paragraphCount = text
        .split(RegExp(r'\n{2,}'))
        .where((p) => p.trim().isNotEmpty)
        .length;
    final imageCount = RegExp(r'!\[.*?\]\(.*?\)|<img').allMatches(text).length;
    final complexityScore = _computeComplexityScore(
      text,
      wordCount: wordCount,
      sentenceCount: sentenceCount,
      isBangla: isBangla,
    );

    return _TextAnalysis(
      wordCount: wordCount,
      charCount: charCount,
      sentenceCount: sentenceCount,
      paragraphCount: paragraphCount,
      imageCount: imageCount,
      complexityScore: complexityScore,
    );
  }

  double _computeComplexityScore(
    String text, {
    required int wordCount,
    required int sentenceCount,
    required bool isBangla,
  }) {
    var score = 1.0;

    // Average sentence length
    final avgSentenceLength = sentenceCount > 0
        ? wordCount / sentenceCount
        : wordCount.toDouble();
    if (avgSentenceLength > 20) score += 0.1;
    if (avgSentenceLength > 30) score += 0.15;
    if (avgSentenceLength > 40) score += 0.15;

    // Technical vocabulary density
    if (isBangla) {
      var techCount = 0;
      for (final word in _banglaTechnicalVocab) {
        if (text.contains(word)) techCount++;
      }
      score += math.min(0.3, techCount * 0.04);
    } else {
      var techCount = 0;
      final lower = text.toLowerCase();
      for (final word in _englishTechnicalIndicators) {
        if (lower.contains(word)) techCount++;
      }
      score += math.min(0.3, techCount * 0.05);
    }

    // Number/data density (requires extra processing time)
    final numberCount = RegExp(r'\d[\d,./]+').allMatches(text).length;
    if (numberCount > 10) score += 0.1;
    if (numberCount > 20) score += 0.1;

    // Acronyms / abbreviations (slow comprehension)
    final acronymCount = RegExp(r'\b[A-Z]{2,5}\b').allMatches(text).length;
    if (acronymCount > 5) score += 0.08;

    // Bangla compound word density (longer tokens = slower parsing)
    if (isBangla) {
      final longBanglaWords = RegExp(
        r'[\u0980-\u09FF]{8,}',
      ).allMatches(text).length;
      final ratio = wordCount > 0 ? longBanglaWords / wordCount : 0.0;
      score += math.min(0.2, ratio * 2.0);
    }

    return score.clamp(1.0, 1.8);
  }

  // ── Word counting ──────────────────────────────────────────────────────────

  int _countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  // Bangla word counting uses Unicode boundary detection
  int _countBanglaWords(String text) {
    // Bangla words are separated by spaces; Unicode chars cluster into tokens
    // Count tokens that contain at least one Bangla character or Latin letter
    final banglaWordRegex = RegExp(r'[\u0980-\u09FF\w]+');
    return banglaWordRegex.allMatches(text).length;
  }

  int _countSentences(String text, {required bool isBangla}) {
    // Bangla sentence-ending marks: ।  (daṇḍa, U+0964) + common English marks
    final pattern = isBangla ? RegExp(r'[।\.!?]+') : RegExp(r'[.!?]+');
    final splits = text.split(pattern).where((s) => s.trim().isNotEmpty).length;
    return math.max(1, splits);
  }

  bool _isBangla(String text) {
    final banglaChars = RegExp(r'[\u0980-\u09FF]').allMatches(text).length;
    return banglaChars > text.length * 0.12;
  }

  double _contentTypeMultiplier(ContentType type) {
    switch (type) {
      case ContentType.news:
        return 1.0;
      case ContentType.opinion:
        return 0.95; // Denser arguments → slightly slower
      case ContentType.feature:
        return 0.92;
      case ContentType.technical:
        return 0.80; // Technical articles slow down significantly
      case ContentType.listicle:
        return 1.10; // Lists are faster to skim
      case ContentType.breaking:
        return 1.05; // Short, punchy
    }
  }

  double _complexityMultiplier(
    _TextAnalysis analysis, {
    required bool isBangla,
  }) {
    return analysis.complexityScore;
  }
}

// ── Supporting types ──────────────────────────────────────────────────────────

enum ReaderSpeed { child, slow, normal, fast, skimmer }

enum ContentType { news, opinion, feature, technical, listicle, breaking }

class _TextAnalysis {
  const _TextAnalysis({
    required this.wordCount,
    required this.charCount,
    required this.sentenceCount,
    required this.paragraphCount,
    required this.imageCount,
    required this.complexityScore,
  });

  final int wordCount;
  final int charCount;
  final int sentenceCount;
  final int paragraphCount;
  final int imageCount;
  final double complexityScore; // 1.0 = simple, 1.8 = very complex
}

class ReadingTimeResult {
  const ReadingTimeResult({
    required this.minutes,
    required this.wordCount,
    required this.characterCount,
    required this.sentenceCount,
    required this.paragraphCount,
    required this.imageCount,
    required this.effectiveWpm,
    required this.complexityScore,
    required this.isBangla,
    required this.readerSpeed,
    required this.contentType,
  });

  final double minutes; // Total reading time in minutes
  final int wordCount;
  final int characterCount;
  final int sentenceCount;
  final int paragraphCount;
  final int imageCount;
  final double effectiveWpm; // Adjusted WPM used for calculation
  final double complexityScore; // 1.0–1.8 text complexity multiplier
  final bool isBangla;
  final ReaderSpeed readerSpeed;
  final ContentType contentType;

  // ── Formatted output ───────────────────────────────────────────────────────

  int get roundedMinutes => math.max(1, minutes.round());

  static const Map<String, String> _banglaDigits = <String, String>{
    '0': '০',
    '1': '১',
    '2': '২',
    '3': '৩',
    '4': '৪',
    '5': '৫',
    '6': '৬',
    '7': '৭',
    '8': '৮',
    '9': '৯',
  };

  static String _formatBanglaNumber(num value) {
    final ascii = value.toString();
    final buffer = StringBuffer();
    for (final rune in ascii.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_banglaDigits[char] ?? char);
    }
    return buffer.toString();
  }

  /// Short format: "৩ মিনিটে পড়ুন" (Bangla)
  String get formattedBn {
    if (minutes < 1) return '১ মিনিটেরও কম';
    if (roundedMinutes == 1) return '১ মিনিটে পড়ুন';
    return '${_formatBanglaNumber(roundedMinutes)} মিনিটে পড়ুন';
  }

  /// Short format: "3 min read" (English)
  String get formattedEn {
    if (minutes < 1) return '< 1 min read';
    if (roundedMinutes == 1) return '1 min read';
    return '$roundedMinutes min read';
  }

  /// Detailed format with word count
  String get detailedEn => '$roundedMinutes min read · $wordCount words';

  /// Detailed format in Bangla
  String get detailedBn =>
      '${_formatBanglaNumber(roundedMinutes)} মিনিট · '
      '${_formatBanglaNumber(wordCount)} শব্দ';

  /// Complexity level label
  String get complexityLabelBn {
    if (complexityScore < 1.2) return 'সহজ';
    if (complexityScore < 1.4) return 'মাঝারি';
    if (complexityScore < 1.6) return 'জটিল';
    return 'অত্যন্ত জটিল';
  }

  String get complexityLabelEn {
    if (complexityScore < 1.2) return 'Easy';
    if (complexityScore < 1.4) return 'Moderate';
    if (complexityScore < 1.6) return 'Complex';
    return 'Very Complex';
  }

  /// Is this a quick read? (useful for UI badges)
  bool get isQuickRead => minutes <= 3;

  /// Is this a long read? (useful for "Long Read" badge)
  bool get isLongRead => minutes >= 10;

  /// Range string for showing fast–slow estimates: "2–4 min"
  String get rangeStringEn {
    final fast = math.max(1, (minutes * 0.7).round());
    final slow = (minutes * 1.3).round();
    return '$fast–$slow min';
  }

  String get rangeStringBn {
    final fast = math.max(1, (minutes * 0.7).round());
    final slow = (minutes * 1.3).round();
    return '${_formatBanglaNumber(fast)}–${_formatBanglaNumber(slow)} মিনিট';
  }

  @override
  String toString() =>
      'ReadingTimeResult($formattedEn, words: $wordCount, '
      'wpm: ${effectiveWpm.toStringAsFixed(0)}, '
      'complexity: ${complexityScore.toStringAsFixed(2)}, '
      'isBangla: $isBangla)';
}
