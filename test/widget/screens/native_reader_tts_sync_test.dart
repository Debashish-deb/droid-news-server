import 'dart:async';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_chunk.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_config.dart';
import 'package:bdnewsreader/core/tts/domain/entities/voice_profile.dart';
import 'package:bdnewsreader/core/tts/domain/repositories/tts_repository.dart';
import 'package:bdnewsreader/core/tts/presentation/providers/tts_controller.dart';
import 'package:bdnewsreader/domain/repositories/settings_repository.dart';
import 'package:bdnewsreader/presentation/features/reader/controllers/reader_controller.dart';
import 'package:bdnewsreader/presentation/features/reader/models/reader_article.dart';
import 'package:bdnewsreader/presentation/features/reader/ui/native_reader_view.dart';
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

class _FakeTtsRepository implements TtsRepository {
  final _chunkIndexController = StreamController<int>.broadcast();
  int? lastSeekIndex;

  @override
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;

  @override
  Stream<double> get progress => const Stream<double>.empty();

  @override
  Future<void> init() async {}

  @override
  Future<List<VoiceProfile>> getAvailableVoices() async =>
      const <VoiceProfile>[];

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(List<TtsChunk> chunks, int startIndex) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(int chunkIndex) async {
    lastSeekIndex = chunkIndex;
    _chunkIndexController.add(chunkIndex);
  }

  @override
  Future<void> stop() async {
    _chunkIndexController.add(-1);
  }

  @override
  Future<void> updateConfig(TtsConfig config) async {}
}

class _SeededReaderController extends ReaderController {
  _SeededReaderController(super.ref) {
    state = state.copyWith(
      isReaderMode: true,
      processedContent:
          '<p><a href="reader://chunk/1" class="reader-sentence reader-sentence-anchor" data-index="1">Second sentence.</a></p>',
      chunks: <TtsChunk>[
        TtsChunk(
          index: 0,
          text: 'First sentence.',
          estimatedDuration: const Duration(milliseconds: 400),
        ),
        TtsChunk(
          index: 1,
          text: 'Second sentence.',
          estimatedDuration: const Duration(milliseconds: 400),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('reader controller seek updates chunk state in reader view', (
    tester,
  ) async {
    final fakeTtsRepository = _FakeTtsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          ttsControllerProvider.overrideWith(
            (ref) => TtsController(fakeTtsRepository),
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

    expect(fakeTtsRepository.lastSeekIndex, 1);
    expect(updatedState.currentChunkIndex, 1);
  });
}
