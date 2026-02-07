import 'dart:math' as math;

/// Reading time estimation service
/// Uses text analysis to predict reading duration
class ReadingTimeEstimator {
  ReadingTimeEstimator._();
  static final ReadingTimeEstimator instance = ReadingTimeEstimator._();

  static const _baseWPM = 225.0;
  static const _fastWPM = 300.0;
  static const _slowWPM = 150.0;

  /// Estimate reading time in minutes
  double estimateReadingTime(String content, {String? title}) {
    final fullText = '${title ?? ''} $content';
    final wordCount = _countWords(fullText);

    if (wordCount == 0) return 0.0;

    var readingTime = wordCount / _baseWPM;

    final complexityFactor = _calculateComplexityFactor(fullText);
    readingTime *= complexityFactor;

    return math.max(1.0, readingTime);
  }

  /// Get formatted reading time string
  String getFormattedReadingTime(double minutes) {
    if (minutes < 1) return '< 1 min read';
    final rounded = minutes.round();
    return '$rounded min read';
  }

  /// Count words in text
  int _countWords(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  /// Calculate text complexity factor
  /// Returns multiplier: 1.0 (normal) to 1.5 (complex)
  double _calculateComplexityFactor(String text) {
    var factor = 1.0;

    final sentences = text.split(RegExp(r'[.!?]+'));
    if (sentences.isNotEmpty) {
      final avgSentenceLength = _countWords(text) / sentences.length;
      if (avgSentenceLength > 25) factor += 0.1;
      if (avgSentenceLength > 35) factor += 0.1;
    }

    final technicalPattern = RegExp(r'\b[A-Z]{2,}\b');
    final technicalMatches = technicalPattern.allMatches(text).length;
    if (technicalMatches > 5) factor += 0.1;

    final numberPattern = RegExp(r'\d+');
    final numberMatches = numberPattern.allMatches(text).length;
    if (numberMatches > 10) factor += 0.1;

    return math.min(1.5, factor);
  }

  /// Estimate based on different reading speeds
  Map<String, double> getReadingTimeOptions(String content, {String? title}) {
    final fullText = '${title ?? ''} $content';
    final wordCount = _countWords(fullText);

    return {
      'fast': wordCount / _fastWPM,
      'normal': wordCount / _baseWPM,
      'slow': wordCount / _slowWPM,
    };
  }
}
