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
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 0.94,
      );

      expect(prosody.role, ChunkRole.attribution);
      expect(prosody.tone, ChunkTone.quote);
      expect(prosody.rate, closeTo(0.44, 0.0001));
    });

    test('inserts pivot comma for transition cues', () {
      final chunk = SpeechChunk(
        id: 3,
        text:
            'Meanwhile the investigation continues and authorities are reviewing evidence from multiple sources.',
        startIndex: 0,
        endIndex: 0,
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 0.94,
      );

      expect(prosody.role, ChunkRole.pivot);
      expect(prosody.text.toLowerCase(), startsWith('meanwhile,'));
    });

    test('keeps natural preset inside human-friendly pitch and rate bounds', () {
      final chunk = SpeechChunk(
        id: 4,
        text:
            'Breaking news! Authorities say the situation remains under control while investigators continue reviewing evidence from multiple sources.',
        startIndex: 0,
        endIndex: 0,
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 0.98,
      );

      expect(prosody.rate, inInclusiveRange(0.38, 0.58));
      expect(prosody.pitch, inInclusiveRange(0.9, 1.1));
    });

    test('keeps rate and pitch stable across different chunk tones', () {
      final chunks = <SpeechChunk>[
        SpeechChunk(
          id: 0,
          text: 'Breaking news! Authorities confirmed the update.',
          startIndex: 0,
          endIndex: 0,
        ),
        SpeechChunk(
          id: 1,
          text: 'According to officials "The work is still ongoing."',
          startIndex: 0,
          endIndex: 0,
        ),
        SpeechChunk(
          id: 2,
          text: 'What happens next?',
          startIndex: 0,
          endIndex: 0,
        ),
      ];

      final prosodies = chunks
          .map(
            (chunk) => TtsProsodyBuilder.buildChunkProsody(
              chunk: chunk,
              baseSynthesisRate: 0.44,
              baseSynthesisPitch: 0.98,
            ),
          )
          .toList();

      expect(prosodies.map((p) => p.tone).toSet(), hasLength(3));
      expect(
        prosodies.map((p) => p.rate.toStringAsFixed(3)).toSet(),
        hasLength(1),
      );
      expect(
        prosodies.map((p) => p.pitch.toStringAsFixed(3)).toSet(),
        hasLength(1),
      );
    });

    test('does not inject dollar placeholders while spacing punctuation', () {
      final chunk = SpeechChunk(
        id: 5,
        text: 'Officials said,however: supplies remain stable!',
        startIndex: 0,
        endIndex: 0,
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 0.94,
      );

      expect(prosody.text, contains('said, however: supplies'));
      expect(prosody.text, isNot(contains(r'$1')));
      expect(prosody.text.toLowerCase(), isNot(contains('dollar')));
    });

    test('shapes Bangla acronyms, numbers, and punctuation naturally', () {
      final chunk = SpeechChunk(
        id: 0,
        text: 'AI খাতে ২৩% প্রবৃদ্ধি হয়েছে. মার্কিন কর্মকর্তারা বলছেন',
        startIndex: 0,
        endIndex: 0,
        language: 'bn-BD',
      );

      final prosody = TtsProsodyBuilder.buildChunkProsody(
        chunk: chunk,
        baseSynthesisRate: 0.44,
        baseSynthesisPitch: 1.0,
      );

      expect(prosody.isBangla, isTrue);
      expect(prosody.text, contains('এ আই'));
      expect(prosody.text, contains('তেইশ শতাংশ'));
      expect(prosody.text, contains('মারকিন'));
      expect(prosody.text.trim(), endsWith('।'));
      expect(prosody.rate, lessThan(0.44));
    });
  });
}
