import 'package:bdnewsreader/core/tts/data/engines/flutter_tts_engine.dart';
import 'package:bdnewsreader/core/tts/data/engines/tts_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterTtsEngine pause timing', () {
    test('keeps comma < sentence-end < paragraph-end ratio', () {
      final engine = FlutterTtsEngine();

      final comma = engine.debugClausePauseMs('This is a sample clause,');
      final sentence = engine.debugSentencePauseMs(
        'This is a complete sentence.',
      );
      final paragraph = engine.debugParagraphPauseMs(
        'This is a complete sentence with enough words for natural pacing.',
      );

      expect(sentence, greaterThanOrEqualTo((comma * 1.8).round()));
      expect(paragraph, greaterThanOrEqualTo((sentence * 1.8).round()));
    });

    test('extends sentence pause for longer context', () {
      final engine = FlutterTtsEngine();

      final shortPause = engine.debugSentencePauseMs('Short line.');
      final longPause = engine.debugSentencePauseMs(
        'This is a significantly longer sentence with multiple contextual details that should naturally require a longer breath before the narrator proceeds.',
      );

      expect(longPause, greaterThan(shortPause));
    });

    test('uses a single paragraph transition pause between paragraphs', () {
      final engine = FlutterTtsEngine();

      const text = 'First paragraph ends here.\n\nSecond paragraph starts now.';
      final pauses = engine.debugPausePlan(
        text,
        language: ArticleLanguage.english,
      );

      final expectedParagraphPause = engine.debugParagraphPauseMs(
        'First paragraph ends here.',
      );

      expect(pauses, hasLength(1));
      expect(pauses.single, expectedParagraphPause);
    });
  });
}
