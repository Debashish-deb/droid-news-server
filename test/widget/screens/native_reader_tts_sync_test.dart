import 'dart:async';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:audio_service/audio_service.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_chunk.dart';
import 'package:bdnewsreader/core/tts/presentation/providers/tts_controller.dart';
import 'package:bdnewsreader/domain/repositories/settings_repository.dart';
import 'package:bdnewsreader/presentation/features/reader/controllers/reader_controller.dart';
import 'package:bdnewsreader/presentation/features/reader/models/reader_article.dart';
import 'package:bdnewsreader/presentation/features/reader/ui/native_reader_view.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/speech_chunk.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_runtime_diagnostics.dart';
import 'package:bdnewsreader/presentation/features/tts/domain/models/tts_session.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_prosody_builder.dart';
import 'package:bdnewsreader/presentation/features/tts/services/tts_runtime_port.dart';
import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<Either<AppFailure, void>> clearRecentSearches() async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, String>> getLanguageCode() async =>
      const Right<AppFailure, String>('en');

  @override
  String getLanguageCodeSync() => 'en';

  @override
  Future<Either<AppFailure, int>> getQuizHighScore() async =>
      const Right<AppFailure, int>(0);

  @override
  Future<Either<AppFailure, int>> getQuizStreak() async =>
      const Right<AppFailure, int>(0);

  @override
  Future<Either<AppFailure, List<String>>> getRecentSearches() async =>
      const Right<AppFailure, List<String>>(<String>[]);

  @override
  Future<Either<AppFailure, double>> getReaderContrast() async =>
      const Right<AppFailure, double>(1.0);

  @override
  double getReaderContrastSync() => 1.0;

  @override
  Future<Either<AppFailure, int>> getReaderFontFamily() async =>
      const Right<AppFailure, int>(0);

  @override
  Future<Either<AppFailure, double>> getReaderFontSize() async =>
      const Right<AppFailure, double>(16.0);

  @override
  Future<Either<AppFailure, double>> getReaderLineHeight() async =>
      const Right<AppFailure, double>(1.6);

  @override
  double getReaderLineHeightSync() => 1.6;

  @override
  Future<Either<AppFailure, int>> getReaderTheme() async =>
      const Right<AppFailure, int>(0);

  @override
  Future<Either<AppFailure, AppThemeMode>> getThemeMode() async =>
      const Right<AppFailure, AppThemeMode>(AppThemeMode.system);

  @override
  AppThemeMode getThemeModeSync() => AppThemeMode.system;

  @override
  Future<Either<AppFailure, void>> saveQuizHighScore(int score) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> saveQuizStreak(int streak) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> saveRecentSearch(String query) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> setLanguageCode(String code) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> setReaderContrast(double contrast) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> setReaderFontFamily(int index) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> setReaderFontSize(double size) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> setReaderLineHeight(double height) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> setReaderTheme(int index) async =>
      const Right<AppFailure, void>(null);

  @override
  Future<Either<AppFailure, void>> setThemeMode(AppThemeMode mode) async =>
      const Right<AppFailure, void>(null);
}

class _FakeTtsRuntime implements TtsRuntimePort {
  final _chunkIndexController = StreamController<int>.broadcast();
  final _sessionController = StreamController<TtsSession?>.broadcast();
  int? lastSeekIndex;
  TtsSession? _session;

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
      articleId: 'reader-test',
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
  Future<void> seekToChunk(int chunkIndex) async {
    lastSeekIndex = chunkIndex;
    _session = _session?.copyWith(currentChunkIndex: chunkIndex);
    _sessionController.add(_session);
    _chunkIndexController.add(chunkIndex);
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
  Future<void> stop() async {
    _chunkIndexController.add(-1);
  }

  void dispose() {
    _chunkIndexController.close();
    _sessionController.close();
  }
}

class _SeededReaderController extends ReaderController {
  _SeededReaderController(super.ref) {
    state = state.copyWith(
      isReaderMode: true,
      processedContent:
          '<p><a href="reader://chunk/1" class="reader-sentence reader-sentence-anchor" data-index="1">Second sentence.</a></p>',
      chunks: <TtsChunk>[
        const TtsChunk(
          index: 0,
          text: 'First sentence.',
          estimatedDuration: Duration(milliseconds: 400),
        ),
        const TtsChunk(
          index: 1,
          text: 'Second sentence.',
          estimatedDuration: Duration(milliseconds: 400),
        ),
      ],
    );
  }
}

class _ProgressiveSeededReaderController extends ReaderController {
  _ProgressiveSeededReaderController(super.ref) {
    final chunks = List<TtsChunk>.generate(20, (index) {
      final text =
          'Chunk $index. This is a deliberately long sentence for staged reader loading verification. '
          'It keeps the synthetic article large enough to trigger phased rendering.';
      return TtsChunk(
        index: index,
        text: text,
        estimatedDuration: const Duration(milliseconds: 250),
      );
    });
    final content = List<String>.generate(20, (index) {
      final text =
          'Chunk $index. This is a deliberately long sentence for staged reader loading verification. '
          'It keeps the synthetic article large enough to trigger phased rendering.';
      return '<p><a href="reader://chunk/$index" class="reader-sentence reader-sentence-anchor" data-index="$index">$text</a></p>';
    }).join();
    state = state.copyWith(
      isReaderMode: true,
      processedContent: content,
      chunks: chunks,
    );
  }
}

void main() {
  test('reader processor annotates TTS sentences with word markers', () {
    final output = processReaderHtmlForTtsIsolate(
      const ReaderHtmlProcessInput(
        content:
            '<article><p>The first sentence is clear. The second sentence follows now.</p></article>',
        articleTitle: 'Reader TTS',
        noiseTokens: <String>[],
        noisyPrefixes: <String>[],
        strictMode: false,
      ),
    );

    expect(output.chunks, hasLength(2));
    expect(output.html, contains('class="reader-word"'));
    expect(output.html, contains('data-sentence-index="0"'));
    expect(output.html, contains('data-word-index="0"'));
    expect(output.html, contains('data-sentence-index="1"'));
  });

  testWidgets('reader controller seek updates chunk state in reader view', (
    tester,
  ) async {
    final fakeTtsRuntime = _FakeTtsRuntime();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          ttsControllerProvider.overrideWith(
            (ref) => TtsController(fakeTtsRuntime),
          ),
          readerControllerProvider.overrideWith(
            (ref) => _SeededReaderController(ref),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderView(
            article: ReaderArticle(
              title: 'Sample Article',
              content: '<p>Fallback content</p>',
              textContent: 'Fallback content',
            ),
          ),
        ),
      ),
    );

    final readerElement = tester.element(find.byType(NativeReaderView));
    final container = ProviderScope.containerOf(readerElement, listen: false);
    final currentState = container.read(readerControllerProvider);

    await tester.pump(const Duration(milliseconds: 300));
    // Prime TtsController with chunks so seekToChunk works
    final ttsController = container.read(ttsControllerProvider.notifier);
    await ttsController.playChunks(currentState.chunks);

    await container.read(readerControllerProvider.notifier).seekToChunk(1);
    await tester.pump(const Duration(milliseconds: 300));

    final updatedState = container.read(readerControllerProvider);

    expect(fakeTtsRuntime.lastSeekIndex, 1);
    expect(updatedState.currentChunkIndex, 1);
  });

  testWidgets('native reader reveals article body in 30/30/40 stages', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          ttsControllerProvider.overrideWith(
            (ref) => TtsController(_FakeTtsRuntime()),
          ),
          readerControllerProvider.overrideWith(
            (ref) => _ProgressiveSeededReaderController(ref),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderView(
            article: ReaderArticle(
              title: 'Large Article',
              content: '<p>Fallback content</p>',
              textContent: 'Fallback content',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    final firstProgress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(firstProgress.value, closeTo(0.30, 0.001));

    await tester.pump(const Duration(milliseconds: 110));
    final secondProgress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(secondProgress.value, closeTo(0.60, 0.001));

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('native reader uses provided TTS handler for smart bar', (
    tester,
  ) async {
    final fakeTtsRuntime = _FakeTtsRuntime();
    var ttsPressedCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          ttsControllerProvider.overrideWith(
            (ref) => TtsController(fakeTtsRuntime),
          ),
          readerControllerProvider.overrideWith(
            (ref) => _SeededReaderController(ref),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NativeReaderView(
            article: const ReaderArticle(
              title: 'Sample Article',
              content: '<p>Fallback content</p>',
              textContent: 'Fallback content',
            ),
            onTtsPressed: () {
              ttsPressedCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_fill));
    await tester.pump();

    expect(ttsPressedCount, 1);
    expect(fakeTtsRuntime.currentSession, isNull);
  });
}
