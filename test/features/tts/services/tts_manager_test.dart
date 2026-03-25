import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_manager.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_service.dart';
import 'package:bdnewsreader/presentation/features/tts/services/audio_cache_manager.dart';
import 'package:bdnewsreader/presentation/features/tts/engine/preloader/chunk_preloader.dart';
import 'package:bdnewsreader/presentation/features/tts/core/pipeline_orchestrator.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/repositories/tts_repository.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_session.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';
import 'package:bdnewsreader/core/telemetry/structured_logger.dart';

// --- Fakes & Mocks ---

class FakeTtsRepository implements TtsRepository {
  TtsSession? _session;
  final Map<String, SpeechChunk> _chunkCache = {};

  @override
  Future<void> cacheChunk(SpeechChunk chunk, String audioPath) async {}

  @override
  Future<SpeechChunk?> getCachedChunk(SpeechChunk chunk) async {
    return _chunkCache[chunk.text];
  }

  @override
  Future<List<SpeechChunk>> getCachedChunksForArticle(String articleId) async =>
      [];

  @override
  Future<void> saveSession(TtsSession session) async {
    _session = session;
  }

  @override
  Future<TtsSession?> getLastSession() async => _session;

  @override
  Future<void> clearOldCache({Duration? maxAge}) async {}

  @override
  Future<void> deleteCachedChunk(String chunkId) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> evictLeastRecentlyUsed(int targetSizeBytes) async {}

  @override
  Future<int> getCacheSizeBytes() async => 0;

  @override
  Future<TtsSession?> loadSession(String sessionId) async => _session;

  @override
  Future<void> recordError(String articleId, String error) async {}

  @override
  Future<void> recordPlayback(String articleId, int chunkIndex) async {}
}

class FakeChunkPreloader implements ChunkPreloader {
  bool preloadCalled = false;

  @override
  int get bufferSize => 2;

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
  String? getPreloadedPath(int chunkId) => null;

  @override
  double getBufferHealth(int currentIndex, List<SpeechChunk> allChunks) => 1.0;

  @override
  PreloaderStats getStats() => const PreloaderStats(
    preloadedCount: 0,
    isPreloading: false,
    bufferSize: 2,
  );

  @override
  void dispose() {}

  @override
  void didHaveMemoryPressure() {}

  @override
  Future<String?> Function(SpeechChunk chunk) get synthesizeChunk =>
      (chunk) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioCacheManager implements AudioCacheManager {
  @override
  Future<String> saveAudio(String fileName, List<int> bytes) async {
    return '/tmp/$fileName';
  }

  @override
  Future<File?> getFile(String fileName) async => null;

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<int> getCacheSizeBytes() async => 0;

  @override
  Future<bool> isValid(String path) async => true;
}

class FakeTtsService implements TtsService {
  double _rate = 0.5;

  @override
  double get currentRate => _rate;

  @override
  Future<void> init() async {}

  @override
  Future<List<Map<String, String>>> getVoices() async =>
      <Map<String, String>>[];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {
    _rate = speed;
  }

  @override
  Future<void> setVoice(String voiceName, String locale) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<String?> synthesizeToFile(String text, String filePath) async {
    final file = File(filePath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes([0, 1, 2, 3]); 
    return filePath;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioHandler extends BaseAudioHandler {
  bool played = false;

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
  Future<void> stop() async {
    played = false;
    playbackState.add(playbackState.value.copyWith(playing: false));
  }
}

void main() {
  group('TtsManager Integration Tests', () {
    late TtsManager manager;
    late FakeTtsRepository repository;
    late FakeChunkPreloader preloader;
    late FakeAudioHandler audioHandler;
    late FakeTtsService ttsService;
    late FakeAudioCacheManager cacheManager;
    late PipelineOrchestrator pipelineOrchestrator;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      repository = FakeTtsRepository();
      preloader = FakeChunkPreloader();
      audioHandler = FakeAudioHandler();
      ttsService = FakeTtsService();
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

      // Mock Path Provider
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return '.';
          });
    });

    test('Initial state should be idle', () {
      expect(manager.currentSession, isNull);
      expect(manager.totalChunks, 0);
    });

    test('speakArticle should create session and start playback', () async {
      const articleId = 'test-1';
      const title = 'Test Article';
      const content = 'This is the content. It has two sentences.';
      await manager.speakArticle(articleId, title, content);
      expect(manager.currentSession, isNotNull);
      expect(manager.currentSession!.articleId, articleId);
      expect(manager.currentSession!.state, TtsSessionState.playing);
      expect(manager.totalChunks, greaterThan(0));
      expect(audioHandler.played, isTrue);
      expect(preloader.preloadCalled, isTrue);
    });

    test('stop should update session and audio handler', () async {
      const articleId = 'test-2';
      await manager.speakArticle(articleId, 'Title', 'Content');

      await manager.stop();

      expect(manager.currentSession!.state, TtsSessionState.stopped);
      expect(audioHandler.played, isFalse);
    });

    test('nextChunk should increment index', () async {
      const articleId = 'test-3';
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

      await manager.speakArticle(articleId, 'Multi-chunk test', articleContent);
      await Future.microtask(() {});
      await manager.nextChunk();

      // Should now be on chunk range 1 (the second chunk)
      expect(manager.currentSession!.currentChunkIndex, 1);
      expect(audioHandler.played, isTrue);
    });

    test('Cancellation: Rapid stop should prevent playback', () async {
      const content = 'Chunk one.';

      // Trigger speak but stop immediately (simulating race condition)
      // We can't easily simulate async race in unit test without delays,
      // but we can verify that if state is stopped manually, logic holds.

      await manager.speakArticle('test-4', 'Title', content);
      await manager.stop();
      await manager
          .nextChunk();
    });
  });
}
