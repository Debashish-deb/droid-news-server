import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:bdnewsreader/core/telemetry/structured_logger.dart';
import 'package:bdnewsreader/presentation/features/tts/core/pipeline_orchestrator.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_session.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/repositories/tts_repository.dart';
import 'package:bdnewsreader/presentation/features/tts/engine/preloader/chunk_preloader.dart';
import 'package:bdnewsreader/presentation/features/tts/services/audio_cache_manager.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_manager.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_player_handler.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_preference_keys.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTtsStorageRepository implements TtsStorageRepository {
  TtsSession? session;
  final Map<String, SpeechChunk> cache = <String, SpeechChunk>{};
  final List<String> deletedChunkIds = <String>[];

  @override
  Future<void> cacheChunk(SpeechChunk chunk, String audioPath) async {}

  @override
  Future<void> clearOldCache({Duration? maxAge}) async {}

  @override
  Future<void> deleteCachedChunk(String chunkId) async {
    deletedChunkIds.add(chunkId);
    cache.removeWhere((_, chunk) => chunk.textHash == chunkId);
  }

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> evictLeastRecentlyUsed(int targetSizeBytes) async {}

  @override
  Future<SpeechChunk?> getCachedChunk(SpeechChunk chunk) async =>
      cache[chunk.text];

  @override
  Future<int> getCacheSizeBytes() async => 0;

  @override
  Future<TtsSession?> getLastSession() async => session;

  @override
  Future<TtsSession?> loadSession(String sessionId) async => session;

  @override
  Future<void> saveSession(TtsSession session) async {
    this.session = session;
  }
}

class FakeChunkPreloader extends ChunkPreloader {
  FakeChunkPreloader() : super(synthesizeChunk: _synthesizeChunk);

  static Future<String?> _synthesizeChunk(SpeechChunk chunk) async => null;

  bool preloadCalled = false;

  @override
  Future<void> preloadAhead({
    required List<SpeechChunk> allChunks,
    required int currentIndex,
  }) async {
    preloadCalled = true;
  }

  @override
  void clear() {}

  @override
  void clearOldPreloads(int currentIndex) {}

  @override
  void didHaveMemoryPressure() {}

  @override
  void dispose() {}

  @override
  double getBufferHealth(int currentIndex, List<SpeechChunk> allChunks) => 1.0;

  @override
  String? getPreloadedPath(int chunkId) => null;

  @override
  PreloaderStats getStats() => const PreloaderStats(
    preloadedCount: 0,
    isPreloading: false,
    bufferSize: 2,
  );
}

class FakeAudioCacheManager implements AudioCacheManager {
  final Set<String> invalidPaths = <String>{};

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<File?> getFile(String fileName) async => null;

  @override
  Future<int> getCacheSizeBytes() async => 0;

  @override
  Future<bool> isValid(String path) async => !invalidPaths.contains(path);

  @override
  Future<String> saveAudio(String fileName, List<int> bytes) async =>
      '/tmp/$fileName';
}

class FakeTtsService implements TtsService {
  FakeTtsService({
    this.synthesizeToFileResult = true,
    this.voices = const <Map<String, String>>[],
  });

  final bool synthesizeToFileResult;
  final List<Map<String, String>> voices;
  double _rate = 0.44;
  int speakCallCount = 0;
  int synthesizeCallCount = 0;
  String? lastVoiceName;
  String? lastVoiceLocale;
  final List<double> rateHistory = <double>[];
  final List<double> pitchHistory = <double>[];

  @override
  double get currentRate => _rate;

  @override
  TtsSynthesisDebugInfo get lastSynthesisDebugInfo =>
      const TtsSynthesisDebugInfo();

  @override
  Future<List<Map<String, String>>> getVoices() async => voices;

  @override
  Future<void> init() async {}

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setPitch(double pitch) async {
    pitchHistory.add(pitch);
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    rateHistory.add(rate);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _rate = speed;
  }

  @override
  Future<void> setVoice(String voiceName, String locale) async {
    lastVoiceName = voiceName;
    lastVoiceLocale = locale;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> speak(String text) async {
    speakCallCount += 1;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<String?> synthesizeToFile(String text, String filePath) async {
    synthesizeCallCount += 1;
    if (!synthesizeToFileResult) return null;
    final file = File(filePath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(const <int>[0, 1, 2, 3]);
    return filePath;
  }
}

class FakeAudioHandler extends BaseAudioHandler {
  bool played = false;
  double? speed;
  bool stopped = false;

  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> play() async {
    played = true;
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    played = true;
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> setSpeed(double speed) async {
    this.speed = speed;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    played = false;
    playbackState.add(playbackState.value.copyWith(playing: false));
  }
}

class FakeQueuedAudioHandler extends FakeAudioHandler
    implements ChunkQueueAudioHandler {
  final Set<int> _queuedChunkIndices = <int>{};
  final List<int> appendedChunks = <int>[];
  final List<int> startedChunks = <int>[];

  @override
  Set<int> get queuedChunkIndices => Set<int>.unmodifiable(_queuedChunkIndices);

  @override
  Future<void> appendQueuedChunk(
    Uri uri, {
    required int chunkIndex,
    Map<String, dynamic>? extras,
  }) async {
    appendedChunks.add(chunkIndex);
    _queuedChunkIndices.add(chunkIndex);
  }

  @override
  Future<void> clearQueuedChunks() async {
    _queuedChunkIndices.clear();
  }

  @override
  Future<void> playQueuedChunk(
    Uri uri, {
    required int chunkIndex,
    Map<String, dynamic>? extras,
  }) async {
    startedChunks.add(chunkIndex);
    _queuedChunkIndices
      ..clear()
      ..add(chunkIndex);
    played = true;
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _queuedChunkIndices.clear();
  }
}

void main() {
  group('TtsManager Integration Tests', () {
    late TtsManager manager;
    late FakeTtsStorageRepository repository;
    late FakeChunkPreloader preloader;
    late FakeAudioHandler audioHandler;
    late FakeTtsService ttsService;
    late FakeAudioCacheManager cacheManager;
    late PipelineOrchestrator pipelineOrchestrator;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});

      repository = FakeTtsStorageRepository();
      preloader = FakeChunkPreloader();
      audioHandler = FakeAudioHandler();
      ttsService = FakeTtsService(
        voices: const <Map<String, String>>[
          <String, String>{'name': 'Bangla Voice', 'locale': 'bn-BD'},
          <String, String>{'name': 'English Voice', 'locale': 'en-US'},
        ],
      );
      cacheManager = FakeAudioCacheManager();
      pipelineOrchestrator = PipelineOrchestrator(StructuredLogger());

      manager = TtsManager.createTestInstance(
        repository: repository,
        preloader: preloader,
        audioHandler: audioHandler,
        ttsService: ttsService,
        cacheManager: cacheManager,
        pipelineOrchestrator: pipelineOrchestrator,
      );

      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return '.';
          });
    });

    test('initial state is idle', () {
      expect(manager.currentSession, isNull);
      expect(manager.totalChunks, 0);
    });

    test('speakArticle creates session and starts playback', () async {
      await manager.speakArticle(
        'test-1',
        'Test Article',
        'This is the content. It has two sentences.',
        category: 'sports',
      );

      expect(manager.currentSession, isNotNull);
      expect(manager.currentSession!.articleId, 'test-1');
      expect(manager.currentSession!.articleCategory, 'sports');
      expect(manager.currentSession!.state, TtsSessionState.playing);
      expect(manager.totalChunks, greaterThan(0));
      expect(audioHandler.played, isTrue);
      expect(preloader.preloadCalled, isTrue);
    });

    test('stop updates session and audio handler', () async {
      await manager.speakArticle('test-2', 'Title', 'Content');

      await manager.stop();

      expect(manager.currentSession!.state, TtsSessionState.stopped);
      expect(audioHandler.played, isFalse);
    });

    test(
      'resume restarts playback when handler is not in a resumable state',
      () async {
        await manager.speakPreparedChunks(
          'resume-fallback',
          'Resume fallback',
          <SpeechChunk>[
            SpeechChunk(
              id: 0,
              text: 'Reader resume fallback chunk.',
              startIndex: 0,
              endIndex: 1,
            ),
          ],
        );

        await manager.pause();
        audioHandler.played = false;
        audioHandler.playbackState.add(
          audioHandler.playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
            playing: false,
          ),
        );

        await manager.resume();

        expect(manager.currentSession!.state, TtsSessionState.playing);
        expect(audioHandler.played, isTrue);
      },
    );

    test('nextChunk increments index for multi-chunk article', () async {
      const articleContent =
          'This is a long and descriptive first section of the article that should be captured as the first chunk. '
          'It contains enough words to satisfy the minimum chunk size requirements of the engine. '
          'We need to make sure this content is very long so that the engine definitely splits it into multiple chunks for testing. '
          'The target chunk size is about 520 characters, so we should aim for significantly more than that, perhaps 1200 characters or more. '
          'Adding more content here to reach that goal. This paragraph is designed to be informative and non-noisy. '
          'Next, we have another substantial paragraph that will form the second part of the speech playback. '
          'This content is carefully crafted to avoid being flagged as noise by the TextCleaner and ChunkEngine filters. '
          'We are adding even more sentences here to ensure we cross the threshold. '
          'The ChunkEngine splits on sentence boundaries, so we need several distinct sentences. '
          'Here is another sentence to help with the length. And another one. '
          'The more content we have, the more reliable the split will be. '
          'Finally, we add some concluding remarks to ensure the total length is well over the target chunk size of 520 characters. '
          'By providing this varied and sufficiently long content, we can reliably test multi-chunk playback and index incrementing logic. '
          'This should now be well over 1000 characters and should definitely result in at least two chunks if not more.';

      await manager.speakArticle('test-3', 'Multi-chunk test', articleContent);
      await Future<void>.microtask(() {});
      await manager.nextChunk();

      expect(manager.currentSession!.currentChunkIndex, 1);
      expect(audioHandler.played, isTrue);
    });

    test(
      'next opens the next feed article before falling back to chunk navigation',
      () async {
        var nextArticleCalls = 0;
        manager.configureFeedNavigation(
          canNextFeedArticle: () => true,
          onNextFeedArticle: () async {
            nextArticleCalls += 1;
          },
        );

        await manager.speakPreparedChunks(
          'feed-nav-test',
          'Feed navigation test',
          <SpeechChunk>[
            SpeechChunk(
              id: 0,
              text: 'First readable chunk for feed navigation.',
              startIndex: 0,
              endIndex: 1,
            ),
            SpeechChunk(
              id: 1,
              text: 'Second readable chunk should not play on feed next.',
              startIndex: 2,
              endIndex: 3,
            ),
          ],
        );

        await manager.next();

        expect(nextArticleCalls, 1);
        expect(manager.currentSession!.currentChunkIndex, 0);
      },
    );

    test(
      'next falls back to the next chunk when no feed article is available',
      () async {
        var nextArticleCalls = 0;
        manager.configureFeedNavigation(
          canNextFeedArticle: () => false,
          onNextFeedArticle: () async {
            nextArticleCalls += 1;
          },
        );

        await manager.speakPreparedChunks(
          'chunk-nav-test',
          'Chunk navigation test',
          <SpeechChunk>[
            SpeechChunk(
              id: 0,
              text: 'First readable chunk for local navigation.',
              startIndex: 0,
              endIndex: 1,
            ),
            SpeechChunk(
              id: 1,
              text: 'Second readable chunk should play on local next.',
              startIndex: 2,
              endIndex: 3,
            ),
          ],
        );

        await manager.next();

        expect(nextArticleCalls, 0);
        expect(manager.currentSession!.currentChunkIndex, 1);
      },
    );

    test('queue-capable handler preloads upcoming chunks into playback queue', () async {
      final queuedHandler = FakeQueuedAudioHandler();
      manager = TtsManager.createTestInstance(
        repository: repository,
        preloader: preloader,
        audioHandler: queuedHandler,
        ttsService: ttsService,
        cacheManager: cacheManager,
        pipelineOrchestrator: pipelineOrchestrator,
      );

      const articleContent =
          'This is a long and descriptive first section of the article that should be captured as the first chunk. '
          'It contains enough words to satisfy the minimum chunk size requirements of the engine. '
          'We need to make sure this content is very long so that the engine definitely splits it into multiple chunks for testing. '
          'The target chunk size is about 520 characters, so we should aim for significantly more than that, perhaps 1200 characters or more. '
          'Adding more content here to reach that goal. This paragraph is designed to be informative and non-noisy. '
          'Next, we have another substantial paragraph that will form the second part of the speech playback. '
          'This content is carefully crafted to avoid being flagged as noise by the TextCleaner and ChunkEngine filters. '
          'We are adding even more sentences here to ensure we cross the threshold. '
          'The ChunkEngine splits on sentence boundaries, so we need several distinct sentences. '
          'Here is another sentence to help with the length. And another one. '
          'The more content we have, the more reliable the split will be. '
          'Finally, we add some concluding remarks to ensure the total length is well over the target chunk size of 520 characters. '
          'By providing this varied and sufficiently long content, we can reliably test multi-chunk playback and index incrementing logic. '
          'This should now be well over 1000 characters and should definitely result in at least two chunks if not more.';

      await manager.speakArticle(
        'queue-test',
        'Queued article',
        articleContent,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(queuedHandler.startedChunks, contains(0));
      expect(queuedHandler.appendedChunks, isNotEmpty);
      expect(preloader.preloadCalled, isFalse);
    });

    test(
      'init does not revive stale resumable session without chunk source',
      () async {
        repository.session =
            TtsSession.create(
              articleId: 'resume-me',
              articleTitle: 'Resume Me',
            ).copyWith(
              totalChunks: 8,
              currentChunkIndex: 3,
              state: TtsSessionState.paused,
            );

        await manager.init();

        expect(manager.currentSession, isNull);
      },
    );

    test('playback speed and synthesis rate persist independently', () async {
      await manager.init();
      await manager.setSpeed(1.35);
      await manager.setRate(0.52);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getDouble(TtsPreferenceKeys.playbackSpeed),
        closeTo(1.35, 0.0001),
      );
      expect(
        prefs.getDouble(TtsPreferenceKeys.synthesisRate),
        closeTo(0.52, 0.0001),
      );
    });

    test(
      'synthesizes every chunk in one article with stable rate and pitch',
      () async {
        await manager.init();
        ttsService.rateHistory.clear();
        ttsService.pitchHistory.clear();

        await manager.speakPreparedChunks(
          'stable-prosody',
          'Stable Prosody',
          <SpeechChunk>[
            SpeechChunk(
              id: 0,
              text: 'Breaking news! Authorities confirmed the update.',
              startIndex: 0,
              endIndex: 1,
            ),
            SpeechChunk(
              id: 1,
              text: 'According to officials "The work is still ongoing."',
              startIndex: 1,
              endIndex: 2,
            ),
            SpeechChunk(
              id: 2,
              text: 'What happens next?',
              startIndex: 2,
              endIndex: 3,
            ),
          ],
        );

        await manager.nextChunk();
        await manager.nextChunk();

        expect(ttsService.synthesizeCallCount, 3);
        expect(
          ttsService.rateHistory.map((v) => v.toStringAsFixed(3)).toSet(),
          hasLength(1),
        );
        expect(
          ttsService.pitchHistory.map((v) => v.toStringAsFixed(3)).toSet(),
          hasLength(1),
        );
      },
    );

    test(
      'bangla article prefers bangla voice rather than english fallback',
      () async {
        await manager.speakArticle(
          'bn-article',
          'বাংলা প্রতিবেদন',
          'এটি একটি বাংলা অনুচ্ছেদ। আরেকটি বাক্য আছে।',
          language: 'bn-BD',
        );

        expect(ttsService.lastVoiceLocale, 'bn-BD');
      },
    );

    test(
      'failed synthesis marks session error and never falls back to direct speak',
      () async {
        ttsService = FakeTtsService(synthesizeToFileResult: false);
        manager = TtsManager.createTestInstance(
          repository: repository,
          preloader: preloader,
          audioHandler: audioHandler,
          ttsService: ttsService,
          cacheManager: cacheManager,
          pipelineOrchestrator: pipelineOrchestrator,
        );

        await manager.speakPreparedChunks(
          'prepared-1',
          'Prepared',
          <SpeechChunk>[
            SpeechChunk(
              id: 0,
              text: 'Failure path chunk.',
              startIndex: 0,
              endIndex: 1,
            ),
          ],
        );

        expect(manager.currentSession, isNotNull);
        expect(manager.currentSession!.state, TtsSessionState.error);
        expect(ttsService.speakCallCount, 0);
        expect(audioHandler.stopped, isTrue);
      },
    );

    test(
      'stale cached audio is evicted and re-synthesized before playback',
      () async {
        const stalePath = '/tmp/stale-reader-audio.wav';
        final staleChunk = SpeechChunk(
          id: 0,
          text: 'Cached but missing chunk.',
          startIndex: 0,
          endIndex: 1,
          language: 'en-US',
          audioPath: stalePath,
        );
        repository.cache[staleChunk.text] = staleChunk;
        cacheManager.invalidPaths.add(stalePath);

        await manager.speakPreparedChunks(
          'prepared-2',
          'Prepared',
          <SpeechChunk>[
            SpeechChunk(
              id: 0,
              text: staleChunk.text,
              startIndex: 0,
              endIndex: 1,
            ),
          ],
        );

        expect(repository.deletedChunkIds, isNotEmpty);
        expect(ttsService.synthesizeCallCount, greaterThan(0));
        expect(manager.diagnostics.usedCachedAudio, isFalse);
        expect(manager.currentSession!.state, TtsSessionState.playing);
        expect(audioHandler.played, isTrue);
      },
    );
  });
}
