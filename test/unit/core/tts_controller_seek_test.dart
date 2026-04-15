import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_chunk.dart';
import 'package:bdnewsreader/core/tts/presentation/providers/tts_controller.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_runtime_diagnostics.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_session.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_prosody_builder.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_runtime_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRuntime implements TtsRuntimePort {
  final _sessionController = StreamController<TtsSession?>.broadcast();
  final _chunkIndexController = StreamController<int>.broadcast();
  TtsSession? _session;
  int? lastSeekIndex;

  @override
  bool get canGoNextFeedArticle => false;

  @override
  bool get canGoPreviousFeedArticle => false;

  @override
  Stream<SpeechChunk?> get currentChunk => const Stream<SpeechChunk?>.empty();

  @override
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;

  @override
  int get currentChunkNumber => (_session?.currentChunkIndex ?? 0) + 1;

  @override
  String get currentArticleTitle => _session?.articleTitle ?? '';

  @override
  String get currentLanguage => 'en-US';

  @override
  TtsRuntimeDiagnostics get currentDiagnostics => const TtsRuntimeDiagnostics();

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
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Duration get estimatedTimeRemaining => Duration.zero;

  @override
  Stream<MediaItem?> get mediaItem => const Stream<MediaItem?>.empty();

  @override
  Stream<PlaybackState> get playbackState =>
      const Stream<PlaybackState>.empty();

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
  Future<void> pause() async {}

  @override
  Future<void> playArticle(
    String articleId,
    String title,
    String content, {
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
  }) async {}

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
    _session = TtsSession.create(
      articleId: 'reader',
      articleTitle: title,
      articleLanguage: language,
      articleCategory: category,
    ).copyWith(totalChunks: chunks.length, state: TtsSessionState.playing);
    _sessionController.add(_session);
  }

  @override
  Future<void> previous() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> retry() async {}

  @override
  Future<void> seekRelative(Duration offset) async {}

  @override
  Future<void> seekToChunk(int index) async {
    lastSeekIndex = index;
    _session = _session?.copyWith(currentChunkIndex: index);
    _sessionController.add(_session);
    _chunkIndexController.add(index);
  }

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setPreset(TtsPreset preset) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  void setSleepTimer(Duration duration) {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVoice(String name, String locale) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}

  void dispose() {
    _sessionController.close();
    _chunkIndexController.close();
  }
}

void main() {
  test(
    'seekToChunk delegates to runtime and updates current chunk state',
    () async {
      final runtime = _FakeRuntime();
      final controller = TtsController(runtime);

      await controller.playChunks(<TtsChunk>[
        const TtsChunk(
          text: 'Chunk 0',
          index: 0,
          estimatedDuration: Duration(seconds: 1),
        ),
        const TtsChunk(
          text: 'Chunk 1',
          index: 1,
          estimatedDuration: Duration(seconds: 1),
        ),
        const TtsChunk(
          text: 'Chunk 2',
          index: 2,
          estimatedDuration: Duration(seconds: 1),
        ),
        const TtsChunk(
          text: 'Chunk 3',
          index: 3,
          estimatedDuration: Duration(seconds: 1),
        ),
      ]);

      await controller.seekToChunk(3);

      expect(runtime.lastSeekIndex, 3);
      expect(controller.state.currentChunk, 3);

      controller.dispose();
      runtime.dispose();
    },
  );
}
