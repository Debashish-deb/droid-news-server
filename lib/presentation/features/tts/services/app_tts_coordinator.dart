// ignore_for_file: annotate_overrides

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:audio_service/audio_service.dart';

import '../../../../core/tts/domain/entities/tts_chunk.dart';
import '../core/bangla_tts_normalizer.dart';
import '../domain/models/speech_chunk.dart';
import '../domain/models/tts_session.dart';
import '../domain/models/tts_runtime_diagnostics.dart';
import 'tts_manager.dart';
import 'tts_prosody_builder.dart' show TtsPreset;
import 'tts_runtime_port.dart';

class AppTtsCoordinator implements TtsRuntimePort {
  AppTtsCoordinator(this._manager);

  final TtsManager _manager;

  Stream<int> get currentChunkIndex => _manager.currentChunkIndex;
  Stream<SpeechChunk?> get currentChunk => _manager.currentChunk;
  Stream<TtsSession?> get sessionStream => _manager.sessionStream;
  Stream<PlaybackState> get playbackState => _manager.playbackState;
  Stream<MediaItem?> get mediaItem => _manager.mediaItem;
  Stream<Duration> get positionStream => _manager.positionStream;
  Stream<Duration> get durationStream => _manager.durationStream;
  Stream<Duration?> get sleepTimerRemaining => _manager.sleepTimerRemaining;
  Stream<TtsRuntimeDiagnostics> get diagnosticsStream =>
      _manager.diagnosticsStream;

  TtsSession? get currentSession => _manager.currentSession;
  TtsRuntimeDiagnostics get currentDiagnostics => _manager.diagnostics;
  int get totalChunks => _manager.totalChunks;
  int get currentChunkNumber => _manager.currentChunkNumber;
  String get currentArticleTitle => _manager.currentArticleTitle;
  Duration get estimatedTimeRemaining => _manager.estimatedTimeRemaining;
  double get currentSpeed => _manager.currentSpeed;
  double get currentPitch => _manager.currentPitch;
  double get currentSynthesisRate => _manager.currentSynthesisRate;
  TtsPreset get currentPreset => _manager.currentPreset;
  String get currentLanguage => _manager.currentLanguage;
  bool get canGoPreviousFeedArticle => _manager.canGoPreviousFeedArticle;
  bool get canGoNextFeedArticle => _manager.canGoNextFeedArticle;

  Future<void> playArticle(
    String articleId,
    String title,
    String content, {
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
    String? introAnnouncement,
  }) {
    return _manager.speakArticle(
      articleId,
      title,
      content,
      language: language,
      category: category,
      author: author,
      imageSource: imageSource,
    );
  }

  Future<void> playReaderChunks(
    List<TtsChunk> chunks, {
    required String title,
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
    String? introAnnouncement,
  }) {
    final articleId = _buildReaderArticleId(title, chunks);
    final preparedChunks = _mapReaderChunks(
      chunks,
      title: title,
      language: language,
      category: category,
      introAnnouncement: introAnnouncement,
    );
    return _manager.speakPreparedChunks(
      articleId,
      title,
      preparedChunks,
      language: language,
      category: category,
      author: author,
      imageSource: imageSource,
    );
  }

  Future<void> pause() => _manager.pause();
  Future<void> resume() => _manager.resume();
  Future<void> retry() => _manager.retry();
  Future<void> stop() => _manager.stop();
  Future<void> seekToChunk(int index) => _manager.seekToChunk(index);
  Future<void> seekRelative(Duration offset) => _manager.seekRelative(offset);
  Future<void> next() => _manager.next();
  Future<void> previous() => _manager.previous();
  Future<void> setSpeed(double speed) => _manager.setSpeed(speed);
  Future<void> setPitch(double pitch) => _manager.setPitch(pitch);
  Future<void> setRate(double rate) => _manager.setRate(rate);
  Future<void> setVolume(double volume) => _manager.setVolume(volume);
  Future<void> setPreset(TtsPreset preset) => _manager.setPreset(preset);
  Future<void> setVoice(String name, String locale) =>
      _manager.setVoice(name, locale);
  Future<List<Map<String, String>>> getAvailableVoices() =>
      _manager.getAvailableVoices();
  void setSleepTimer(Duration duration) => _manager.setSleepTimer(duration);
  void configureFeedNavigation({
    Future<void> Function()? onPreviousFeedArticle,
    Future<void> Function()? onNextFeedArticle,
    bool Function()? canPreviousFeedArticle,
    bool Function()? canNextFeedArticle,
  }) {
    _manager.configureFeedNavigation(
      onPreviousFeedArticle: onPreviousFeedArticle,
      onNextFeedArticle: onNextFeedArticle,
      canPreviousFeedArticle: canPreviousFeedArticle,
      canNextFeedArticle: canNextFeedArticle,
    );
  }

  void clearFeedNavigation() => _manager.clearFeedNavigation();

  String _buildReaderArticleId(String title, List<TtsChunk> chunks) {
    final buffer = StringBuffer(title.trim());
    for (final chunk in chunks.take(12)) {
      buffer
        ..write('|')
        ..write(chunk.index)
        ..write(':')
        ..write(chunk.text);
    }
    final digest = sha1.convert(utf8.encode(buffer.toString())).toString();
    return 'reader_$digest';
  }

  List<SpeechChunk> _mapReaderChunks(
    List<TtsChunk> chunks, {
    required String title,
    required String language,
    required String category,
    String? introAnnouncement,
  }) {
    final shouldPrefixTitle =
        title.trim().isNotEmpty && !chunks.any((chunk) => chunk.isTitleChunk);
    final titlePreamble = shouldPrefixTitle
        ? _readerTitlePreamble(title, language: language)
        : '';
    final intro = introAnnouncement?.trim() ?? '';
    var runtimeIndex = 0;
    return chunks
        .map((chunk) {
          final isFirstChunk = runtimeIndex == 0;
          final spokenText = isFirstChunk
              ? [
                  if (intro.isNotEmpty) intro,
                  if (titlePreamble.isNotEmpty) titlePreamble,
                  chunk.text,
                ].join(' ')
              : chunk.text;
          return SpeechChunk(
            id: runtimeIndex++,
            text: spokenText,
            startIndex: chunk.index,
            endIndex: chunk.index,
            language: language,
            articleCategory: category,
            isArticleLead:
                chunk.isTitleChunk || isFirstChunk || chunk.index == 0,
            isParagraphStart: chunk.sentenceIndexInParagraph == 0,
            isParagraphEnd: _sentenceEndPattern.hasMatch(spokenText.trim()),
            minorPauseCount: _minorPausePattern.allMatches(spokenText).length,
            majorPauseCount: _majorPausePattern.allMatches(spokenText).length,
            pauseBoundary: _pauseBoundaryFor(spokenText),
          );
        })
        .toList(growable: false);
  }

  String _readerTitlePreamble(String title, {required String language}) {
    final trimmed = title.trim();
    final isBangla =
        language.toLowerCase().startsWith('bn') ||
        BanglaTtsNormalizer.hasBangla(trimmed);
    if (!isBangla) {
      final titleText = RegExp(r'[.!?]$').hasMatch(trimmed)
          ? trimmed
          : '$trimmed.';
      return 'Title. $titleText Full story.';
    }
    final normalizedTitle = BanglaTtsNormalizer.withBanglaTerminal(
      BanglaTtsNormalizer.normalize(trimmed),
    );
    return 'শিরোনাম। $normalizedTitle বিস্তারিত সংবাদ।';
  }

  String _pauseBoundaryFor(String text) {
    final trimmed = text.trimRight();
    if (trimmed.endsWith('\n\n')) return 'paragraphEnd';
    if (_sentenceEndPattern.hasMatch(trimmed)) return 'sentenceEnd';
    if (_majorPausePattern.hasMatch(trimmed)) return 'clauseMajor';
    if (_minorPausePattern.hasMatch(trimmed)) return 'clauseMinor';
    return 'none';
  }

  static final RegExp _minorPausePattern = RegExp(r'[,;:]');
  static final RegExp _majorPausePattern = RegExp(r'[.!?।]');
  static final RegExp _sentenceEndPattern = RegExp(r'[.!?।]\s*$');
}
