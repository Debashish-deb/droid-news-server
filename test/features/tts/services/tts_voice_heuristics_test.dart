import 'package:bdnewsreader/core/tts/shared/tts_voice_heuristics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsVoiceHeuristics', () {
    test('filters novelty voices such as echo and electro when alternatives exist', () {
      final candidates = <TtsVoiceCandidate>[
        const TtsVoiceCandidate(name: 'Echo', locale: 'en-US'),
        const TtsVoiceCandidate(name: 'Electro Voice', locale: 'en-US'),
        const TtsVoiceCandidate(
          name: 'English Neural',
          locale: 'en-US',
          isNetworkVoice: true,
        ),
      ];

      final sanitized = TtsVoiceHeuristics.sanitizeCandidates(candidates);

      expect(sanitized, hasLength(1));
      expect(sanitized.single.name, 'English Neural');
    });

    test('prefers matching natural voices for the requested language', () {
      final best = TtsVoiceHeuristics.pickBestVoiceMap(
        const <Map<String, String>>[
          <String, String>{'name': 'Generic English', 'locale': 'en-US'},
          <String, String>{'name': 'Bangla Natural', 'locale': 'bn-BD'},
          <String, String>{'name': 'Hindi Voice', 'locale': 'hi-IN'},
        ],
        preferredLanguageCode: 'bn',
      );

      expect(best, isNotNull);
      expect(best!['name'], 'Bangla Natural');
      expect(best['locale'], 'bn-BD');
    });
  });
}
