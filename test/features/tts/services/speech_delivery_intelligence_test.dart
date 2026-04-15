import 'package:bdnewsreader/presentation/features/tts/services/speech_delivery_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechDeliveryIntelligence', () {
    test('detects article and paragraph boundaries from raw chunk markers', () {
      const rawText =
          '[ARTICLE_START] [PARAGRAPH_START] Breaking update, officials confirm the move. [PARAGRAPH_END]';

      final analysis = SpeechDeliveryIntelligence.analyzeRawChunkText(rawText);

      expect(analysis.isArticleLead, isTrue);
      expect(analysis.isParagraphStart, isTrue);
      expect(analysis.isParagraphEnd, isTrue);
      expect(analysis.minorPauseCount, 1);
      expect(analysis.boundary, SpeechPauseBoundary.paragraphEnd);
    });

    test('maps solemn and breaking categories to distinct profiles', () {
      final breaking = SpeechDeliveryIntelligence.profileForCategory('breaking');
      final solemn = SpeechDeliveryIntelligence.profileForCategory('obituary');

      expect(breaking.normalizedCategory, 'breaking');
      expect(solemn.normalizedCategory, 'solemn');
      expect(breaking.rateBias, greaterThan(solemn.rateBias));
      expect(breaking.pitchBias, greaterThan(solemn.pitchBias));
    });
  });
}
