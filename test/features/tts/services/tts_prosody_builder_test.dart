import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_prosody_builder.dart';

void main() {
  group('TtsProsodyBuilder', () {
    test('normalizes markers and broadcast numbers for lead chunks', () {
      final chunk = SpeechChunk(
        id: 0,
        text:
            '[LEAD] Breaking news [PAUSE 1.0s] Officials report \$1.2B losses and 23% decline.',
        startIndex: 0,
        endIndex: 0,
        language: 'en',
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 0.94,
      );

      expect(prosody.role, ChunkRole.lead);
      expect(prosody.text, isNot(contains('[PAUSE')));
      expect(
        prosody.text.toLowerCase(),
        contains('one point two billion dollars'),
      );
      expect(prosody.text.toLowerCase(), contains('twenty three percent'));
    });

    test('detects attribution and quote shaping', () {
      final chunk = SpeechChunk(
        id: 2,
        text: 'According to officials "We are monitoring the situation."',
        startIndex: 0,
        endIndex: 0,
        language: 'en',
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 0.94,
      );

      expect(prosody.role, ChunkRole.attribution);
      expect(prosody.tone, ChunkTone.quote);
      expect(prosody.rate, lessThan(0.44));
    });

    test('inserts pivot comma for transition cues', () {
      final chunk = SpeechChunk(
        id: 3,
        text:
            'Meanwhile the investigation continues and authorities are reviewing evidence from multiple sources.',
        startIndex: 0,
        endIndex: 0,
        language: 'en',
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 0.94,
      );

      expect(prosody.role, ChunkRole.pivot);
      expect(prosody.text.toLowerCase(), startsWith('meanwhile,'));
    });
  });
}
