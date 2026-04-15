import 'package:bdnewsreader/infrastructure/services/ml/reading_time_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReadingTimeResult buildResult({
    required double minutes,
    required int wordCount,
  }) {
    return ReadingTimeResult(
      minutes: minutes,
      wordCount: wordCount,
      characterCount: wordCount * 5,
      sentenceCount: 4,
      paragraphCount: 2,
      imageCount: 0,
      effectiveWpm: 165,
      complexityScore: 1.1,
      isBangla: true,
      readerSpeed: ReaderSpeed.normal,
      contentType: ContentType.news,
    );
  }

  test('Bangla formatted strings use Bangla digits', () {
    final result = buildResult(minutes: 12, wordCount: 345);

    expect(result.formattedBn, '১২ মিনিটে পড়ুন');
    expect(result.detailedBn, '১২ মিনিট · ৩৪৫ শব্দ');
    expect(result.rangeStringBn, '৮–১৬ মিনিট');
  });

  test('English formatted strings keep ASCII digits', () {
    final result = buildResult(minutes: 12, wordCount: 345);

    expect(result.formattedEn, '12 min read');
    expect(result.detailedEn, '12 min read · 345 words');
  });
}
