import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_chunk.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_state.dart'
    show TtsStatus;
import 'package:bdnewsreader/core/tts/domain/entities/voice_profile.dart';
import 'package:bdnewsreader/core/tts/presentation/providers/tts_controller.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_runtime_diagnostics.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_session.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_prosody_builder.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_runtime_port.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTtsRuntime implements TtsRuntimePort {
  final StreamController<int> _chunkIndexController =
      StreamController<int>.broadcast();
  final StreamController<SpeechChunk?> _chunkController =
      StreamController<SpeechChunk?>.broadcast();
  final StreamController<TtsSession?> _sessionController =
      StreamController<TtsSession?>.broadcast();
  final StreamController<PlaybackState> _playbackController =
      StreamController<PlaybackState>.broadcast();

  int playArticleCalls = 0;
  int playReaderChunkCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int? lastSeekIndex;
  Duration? lastSeekOffset;
  double? lastRate;
  double? lastPitch;
  String? lastVoiceName;
  String? lastVoiceLocale;
  Object? playArticleError;
  Object? playReaderChunksError;
  TtsSession? _session;

  @override
  bool get canGoNextFeedArticle => false;

  @override
  bool get canGoPreviousFeedArticle => false;

  @override
  Stream<SpeechChunk?> get currentChunk => _chunkController.stream;

  @override
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;

  @override
  int get currentChunkNumber => (_session?.currentChunkIndex ?? 0) + 1;

  @override
  String get currentArticleTitle => _session?.articleTitle ?? '';

  @override
  String get currentLanguage => _session?.articleLanguage ?? 'en-US';

  @override
  double get currentPitch => 0.98;

  @override
  TtsPreset get currentPreset => TtsPreset.natural;

  @override
  double get currentSpeed => 1.0;

  @override
  double get currentSynthesisRate => 0.44;

  @override
  TtsSession? get currentSession => _session;

  @override
  TtsRuntimeDiagnostics get currentDiagnostics => const TtsRuntimeDiagnostics();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Duration get estimatedTimeRemaining => Duration.zero;

  @override
  Stream<MediaItem?> get mediaItem => const Stream<MediaItem?>.empty();

  @override
  Stream<PlaybackState> get playbackState => _playbackController.stream;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<TtsSession?> get sessionStream => _sessionController.stream;

  @override
  Stream<Duration?> get sleepTimerRemaining => const Stream<Duration?>.empty();

  @override
  Stream<TtsRuntimeDiagnostics> get diagnosticsStream =>
      const Stream<TtsRuntimeDiagnostics>.empty();

  @override
  int get totalChunks => _session?.totalChunks ?? 0;

  @override
  Future<List<Map<String, String>>> getAvailableVoices() async =>
      const <Map<String, String>>[];

  @override
  Future<void> next() async {}

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    if (_session != null) {
      _session = _session!.copyWith(state: TtsSessionState.paused);
      _sessionController.add(_session);
    }
  }

  @override
  Future<void> playArticle(
    String articleId,
    String title,
    String content, {
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
    String? introAnnouncement,
  }) async {
    if (playArticleError != null) {
      throw playArticleError!;
    }
    playArticleCalls += 1;
    _session = TtsSession.create(
      articleId: articleId,
      articleTitle: title,
      articleCategory: category,
      articleLanguage: language,
    ).copyWith(totalChunks: 1, state: TtsSessionState.playing);
    _sessionController.add(_session);
  }

  @override
  Future<void> playReaderChunks(
    List<TtsChunk> chunks, {
    required String title,
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
    String? introAnnouncement,
  }) async {
    if (playReaderChunksError != null) {
      throw playReaderChunksError!;
    }
    playReaderChunkCalls += 1;
    _session = TtsSession.create(
      articleId: 'reader',
      articleTitle: title,
      articleCategory: category,
      articleLanguage: language,
    ).copyWith(totalChunks: chunks.length, state: TtsSessionState.playing);
    _sessionController.add(_session);
  }

  @override
  Future<void> previous() async {}

  @override
  Future<void> resume() async {
    resumeCalls += 1;
    if (_session != null) {
      _session = _session!.copyWith(state: TtsSessionState.playing);
      _sessionController.add(_session);
    }
  }

  @override
  Future<void> retry() async {
    if (_session != null) {
      _session = _session!.copyWith(
        state: TtsSessionState.playing,
        errorMessage: null,
      );
      _sessionController.add(_session);
    }
  }

  @override
  Future<void> seekRelative(Duration offset) async {
    lastSeekOffset = offset;
  }

  @override
  Future<void> seekToChunk(int index) async {
    lastSeekIndex = index;
    if (_session != null) {
      _session = _session!.copyWith(currentChunkIndex: index);
      _sessionController.add(_session);
    }
    _chunkIndexController.add(index);
  }

  @override
  Future<void> setPitch(double pitch) async {
    lastPitch = pitch;
  }

  @override
  Future<void> setPreset(TtsPreset preset) async {}

  @override
  Future<void> setRate(double rate) async {
    lastRate = rate;
  }

  @override
  void setSleepTimer(Duration duration) {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVoice(String name, String locale) async {
    lastVoiceName = name;
    lastVoiceLocale = locale;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (_session != null) {
      _session = _session!.copyWith(state: TtsSessionState.stopped);
      _sessionController.add(_session);
    }
  }

  void dispose() {
    _chunkIndexController.close();
    _chunkController.close();
    _sessionController.close();
    _playbackController.close();
  }
}

void main() {
  group('TTS Controller', () {
    late FakeTtsRuntime runtime;
    late TtsController controller;

    setUp(() {
      runtime = FakeTtsRuntime();
      controller = TtsController(runtime);
    });

    tearDown(() {
      controller.dispose();
      runtime.dispose();
    });

    test('playFromText delegates to shared runtime article playback', () async {
      await controller.playFromText('Hello world');

      expect(runtime.playArticleCalls, 1);
      expect(controller.state.status, TtsStatus.playing);
    });

    test(
      'playChunks delegates to shared runtime prepared chunk playback',
      () async {
        await controller.playChunks(<TtsChunk>[
          const TtsChunk(
            text: 'Chunk 0',
            index: 0,
            estimatedDuration: Duration(seconds: 1),
          ),
        ]);

        expect(runtime.playReaderChunkCalls, 1);
        expect(controller.state.totalChunks, 1);
      },
    );

    test('playChunks surfaces startup failures as error state', () async {
      runtime.playReaderChunksError = StateError('TTS init failed');

      await controller.playChunks(<TtsChunk>[
        const TtsChunk(
          text: 'Chunk 0',
          index: 0,
          estimatedDuration: Duration(seconds: 1),
        ),
      ]);

      expect(controller.state.status, TtsStatus.error);
      expect(controller.state.error, contains('TTS init failed'));
    });

    test('successful playback clears previous error state', () async {
      runtime.playReaderChunksError = StateError('TTS init failed');
      await controller.playChunks(<TtsChunk>[
        const TtsChunk(
          text: 'Chunk 0',
          index: 0,
          estimatedDuration: Duration(seconds: 1),
        ),
      ]);

      runtime.playReaderChunksError = null;
      await controller.playChunks(<TtsChunk>[
        const TtsChunk(
          text: 'Chunk 0',
          index: 0,
          estimatedDuration: Duration(seconds: 1),
        ),
      ]);

      expect(controller.state.status, TtsStatus.playing);
      expect(controller.state.error, isNull);
    });

    test('pause, resume, stop delegate to shared runtime', () async {
      await controller.playFromText('Test');
      await controller.pause();
      await controller.resume();
      await controller.stop();

      expect(runtime.pauseCalls, 1);
      expect(runtime.resumeCalls, 1);
      expect(runtime.stopCalls, greaterThanOrEqualTo(1));
    });

    test('setRate and setPitch update config and runtime', () async {
      await controller.setRate(0.5);
      await controller.setPitch(1.02);

      expect(runtime.lastRate, closeTo(0.5, 0.0001));
      expect(runtime.lastPitch, closeTo(1.02, 0.0001));
      expect(controller.state.config.rate, closeTo(0.5, 0.0001));
      expect(controller.state.config.pitch, closeTo(1.02, 0.0001));
    });

    test('setVoice delegates to runtime voice selection', () async {
      await controller.setVoice(
        const VoiceProfile(name: 'Natural', locale: 'bn-BD'),
      );

      expect(runtime.lastVoiceName, 'Natural');
      expect(runtime.lastVoiceLocale, 'bn-BD');
    });

    test(
      'seekRelative delegates relative playback movement to runtime',
      () async {
        await controller.seekRelative(const Duration(seconds: 10));

        expect(runtime.lastSeekOffset, const Duration(seconds: 10));
      },
    );

    test('empty text does not start playback', () async {
      await controller.playFromText('');

      expect(runtime.playArticleCalls, 0);
    });

    test('dispose stops shared runtime', () {
      final localRuntime = FakeTtsRuntime();
      final localController = TtsController(localRuntime);

      localController.dispose();

      expect(localRuntime.stopCalls, 1);
      localRuntime.dispose();
    });
  });
}
