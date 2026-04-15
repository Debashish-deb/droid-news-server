import 'package:bdnewsreader/presentation/features/tts/services/adaptive_speech_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdaptiveSpeechProfileStore', () {
    late AdaptiveSpeechProfileStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = AdaptiveSpeechProfileStore();
    });

    test('records and resolves per-category corrections', () async {
      await store.recordPitchCorrection(
        language: 'en-US',
        category: 'sports',
        pitch: 1.02,
      );
      await store.recordPlaybackPaceCorrection(
        language: 'en-US',
        category: 'sports',
        playbackSpeed: 1.25,
      );
      await store.recordPresetCorrection(
        language: 'en-US',
        category: 'sports',
        presetName: 'anchor',
      );

      final profile = await store.resolve(
        language: 'en-US',
        category: 'sports',
      );

      expect(profile.correctionCount, greaterThan(0));
      expect(profile.preferredPresetName, 'anchor');
      expect(profile.pitchBias, isNonZero);
      expect(profile.rateBias, isNonZero);
    });
  });
}
