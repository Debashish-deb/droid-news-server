import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentation/features/tts/domain/models/tts_session.dart';
import '../../../../presentation/providers/feature_providers.dart';
import '../../../../presentation/features/tts/services/tts_runtime_port.dart';
import '../../data/chunking/chunk_scheduler.dart';
import '../../data/engines/tts_engine.dart';
import '../../domain/entities/tts_chunk.dart';
import '../../domain/entities/tts_config.dart';
import '../../domain/entities/tts_state.dart';
import '../../domain/entities/voice_profile.dart';

final ttsControllerProvider = StateNotifierProvider<TtsController, TtsState>((
  ref,
) {
  final runtime = ref.watch(appTtsCoordinatorProvider);
  final controller = TtsController(runtime);
  ref.onDispose(controller.dispose);
  return controller;
});

class TtsController extends StateNotifier<TtsState> {
  TtsController(this._runtime) : super(TtsState.idle()) {
    _syncConfigFromRuntime();
    _listenToRuntime();
  }

  final TtsRuntimePort _runtime;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<TtsChunk> _chunks = [];
  PlaybackState _lastPlaybackState = PlaybackState();

  // ── Seek debounce ──────────────────────────────────────────────────────────
  Timer? _seekDebounceTimer;
  static const _seekDebounceDuration = Duration(milliseconds: 300);

  // ── Position estimation ────────────────────────────────────────────────────
  Timer? _positionTimer;
  DateTime? _chunkStartTime;
  Duration _basePositionOffset = Duration.zero;

  // ─── Initialisation ────────────────────────────────────────────────────────

  void _listenToRuntime() {
    _subscriptions.add(
      _runtime.sessionStream.listen((session) {
        if (!mounted) return;

        if (session == null) {
          _stopPositionTimer();
          state = TtsState.idle().copyWith(config: state.config, error: null);
          _chunks = [];
          return;
        }

        final resolvedStatus = _resolveStatus(
          session.state,
          _lastPlaybackState,
        );

        // Start or stop the position estimator based on whether we're playing.
        if (resolvedStatus == TtsStatus.playing) {
          _startPositionTimer();
        } else {
          _stopPositionTimer();
        }

        state = state.copyWith(
          status: resolvedStatus,
          currentChunk: session.currentChunkIndex,
          totalChunks: session.totalChunks,
          progressFraction: session.progress,
          language: session.articleLanguage,
          error: session.errorMessage,
          config: state.config.copyWith(languageCode: session.articleLanguage),
        );

        // Anchor the position estimator at the new chunk boundary.
        _chunkStartTime = DateTime.now();
        _basePositionOffset = _estimateOffsetUpToChunk(
          session.currentChunkIndex,
        );
      }),
    );

    _subscriptions.add(
      _runtime.playbackState.listen((playback) {
        if (!mounted) return;
        _lastPlaybackState = playback;
        final session = _runtime.currentSession;
        if (session == null) return;

        final resolvedStatus = _resolveStatus(session.state, playback);
        if (resolvedStatus == TtsStatus.playing) {
          _startPositionTimer();
        } else {
          _stopPositionTimer();
        }

        state = state.copyWith(status: resolvedStatus);
      }),
    );
  }

  // ─── Playback commands ─────────────────────────────────────────────────────

  Future<void> playFromText(
    String text, {
    String? title,
    String? author,
    String? imageSource,
    String language = 'en',
    String category = 'general',
    HumanizationConfig? humanization,
    int startChunkIndex = 0,
  }) async {
    if (text.trim().isEmpty) return;

    state = state.copyWith(
      status: TtsStatus.loading,
      language: language,
      error: null,
      config: state.config.copyWith(
        languageCode: language,
        humanization: humanization ?? state.config.humanization,
      ),
    );

    final articleTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Article';
    final articleId = _buildArticleId(articleTitle, text, language, category);

    try {
      await _runtime.playArticle(
        articleId,
        articleTitle,
        text,
        language: language,
        category: category,
        author: author,
        imageSource: imageSource,
      );

      _chunks = ChunkScheduler.buildChunks(
        text,
        title: title,
        author: author,
        imageSource: imageSource,
        language: language,
      );

      final clampedStart = startChunkIndex.clamp(0, _chunks.length - 1);
      if (clampedStart > 0) {
        await _runtime.seekToChunk(clampedStart);
      }
    } catch (error) {
      _setPlaybackError(error, language: language);
    }
  }

  Future<void> playChunks(
    List<TtsChunk> chunks, {
    int startIndex = 0,
    String category = 'general',
    String? language,
    String? title,
    String? author,
    String? imageSource,
    String? introAnnouncement,
  }) async {
    if (chunks.isEmpty) return;

    final resolvedLanguage = language ?? _inferLanguageFromChunks(chunks);
    final resolvedTitle =
        title ??
        chunks
            .firstWhere((c) => c.isTitleChunk, orElse: () => chunks.first)
            .text;

    _chunks = chunks;
    state = state.copyWith(
      status: TtsStatus.loading,
      currentChunk: startIndex.clamp(0, chunks.length - 1),
      totalChunks: chunks.length,
      language: resolvedLanguage,
      error: null,
      config: state.config.copyWith(languageCode: resolvedLanguage),
    );

    try {
      await _runtime.playReaderChunks(
        chunks,
        title: resolvedTitle,
        language: resolvedLanguage,
        category: category,
        author: author,
        imageSource: imageSource,
        introAnnouncement: introAnnouncement,
      );

      final clampedStart = startIndex.clamp(0, chunks.length - 1);
      if (clampedStart > 0) {
        await _runtime.seekToChunk(clampedStart);
      }
    } catch (error) {
      _setPlaybackError(error, language: resolvedLanguage);
    }
  }

  Future<void> pause() async {
    _stopPositionTimer();
    await _runtime.pause();
    if (mounted) state = state.copyWith(status: TtsStatus.paused);
  }

  Future<void> resume() async {
    await _runtime.resume();
    if (mounted) {
      state = state.copyWith(status: TtsStatus.playing);
      _startPositionTimer();
    }
  }

  Future<void> retry() async {
    final language = state.language;
    if (mounted) state = state.copyWith(status: TtsStatus.loading, error: null);
    try {
      await _runtime.retry();
    } catch (error) {
      _setPlaybackError(error, language: language);
    }
  }

  Future<void> stop() async {
    _stopPositionTimer();
    _cancelSeekDebounce();
    await _runtime.stop();
    if (mounted) {
      state = TtsState.idle().copyWith(config: state.config, error: null);
      _chunks = [];
    }
  }

  Future<void> togglePlayPause() async {
    switch (state.status) {
      case TtsStatus.playing:
      case TtsStatus.buffering:
      case TtsStatus.loading:
        return pause();
      case TtsStatus.paused:
        return resume();
      case TtsStatus.error:
        return retry();
      default:
        return;
    }
  }

  // ─── Navigation ────────────────────────────────────────────────────────────

  /// `true` when there is a next sentence to navigate to.
  bool get canGoNextChunk => state.currentChunk < _chunks.length - 1;

  /// `true` when there is a previous sentence to navigate to.
  bool get canGoPreviousChunk => state.currentChunk > 0;

  /// Jump to the next sentence chunk.
  Future<void> nextChunk() => seekToChunk(state.currentChunk + 1);

  /// Jump to the previous sentence chunk.
  Future<void> previousChunk() => seekToChunk(state.currentChunk - 1);

  /// Seeks to an absolute chunk [chunkIndex], clamped to valid bounds.
  Future<void> seekToChunk(int chunkIndex) async {
    if (_chunks.isEmpty) return;
    final clamped = chunkIndex.clamp(0, _chunks.length - 1);
    await _runtime.seekToChunk(clamped);
    if (mounted) {
      _basePositionOffset = _estimateOffsetUpToChunk(clamped);
      _chunkStartTime = DateTime.now();
      state = state.copyWith(
        currentChunk: clamped,
        progressFraction: _chunks.isEmpty ? 0 : clamped / _chunks.length,
        estimatedPosition: _basePositionOffset,
      );
    }
  }

  /// Seeks forward or backward by [offset].
  ///
  /// Calls are debounced to avoid hammering the runtime with rapid scrubs.
  Future<void> seekRelative(Duration offset) {
    _cancelSeekDebounce();
    final completer = Completer<void>();
    _seekDebounceTimer = Timer(_seekDebounceDuration, () async {
      try {
        await _runtime.seekRelative(offset);
        if (mounted) {
          final newPos = _clampDuration(
            state.estimatedPosition + offset,
            min: Duration.zero,
            max: _totalEstimatedDuration,
          );
          _basePositionOffset = newPos;
          _chunkStartTime = DateTime.now();
          state = state.copyWith(estimatedPosition: newPos);
        }
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<void> next() => _runtime.next();
  Future<void> previous() => _runtime.previous();

  // ─── Configuration ─────────────────────────────────────────────────────────

  Future<void> updateConfig(TtsConfig config) async {
    if ((config.rate - state.config.rate).abs() > 0.0001) {
      await _runtime.setRate(config.rate);
    }
    if ((config.pitch - state.config.pitch).abs() > 0.0001) {
      await _runtime.setPitch(config.pitch);
    }
    if (mounted) state = state.copyWith(config: config);
  }

  Future<void> setHumanization(HumanizationConfig config) async {
    if (mounted) {
      state = state.copyWith(
        config: state.config.copyWith(humanization: config),
      );
    }
  }

  Future<void> setRate(double rate) async {
    await _runtime.setRate(rate);
    if (mounted) {
      state = state.copyWith(config: state.config.copyWith(rate: rate));
    }
  }

  Future<void> setPitch(double pitch) async {
    await _runtime.setPitch(pitch);
    if (mounted) {
      state = state.copyWith(config: state.config.copyWith(pitch: pitch));
    }
  }

  Future<void> setVoice(VoiceProfile voice) async {
    await _runtime.setVoice(voice.name, voice.locale);
    if (mounted) {
      state = state.copyWith(config: state.config.copyWith(voice: voice.name));
    }
  }

  // ─── Read-only accessors ───────────────────────────────────────────────────

  /// The chunk currently being spoken, or `null` when idle.
  TtsChunk? get currentChunk {
    final idx = state.currentChunk;
    if (idx < 0 || idx >= _chunks.length) return null;
    return _chunks[idx];
  }

  /// Immutable view of the full chunk list.
  List<TtsChunk> get chunks => List.unmodifiable(_chunks);

  /// Returns the chunk at [index], or `null` if out of bounds.
  TtsChunk? chunkAt(int index) {
    if (index < 0 || index >= _chunks.length) return null;
    return _chunks[index];
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stopPositionTimer();
    _cancelSeekDebounce();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    unawaited(_runtime.stop());
    super.dispose();
  }

  // ─── Position estimation ───────────────────────────────────────────────────

  void _startPositionTimer() {
    if (_positionTimer?.isActive == true) return;
    _chunkStartTime ??= DateTime.now();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _tickPosition(),
    );
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _tickPosition() {
    if (!mounted || !state.isPlaying) return;
    final elapsed = _chunkStartTime != null
        ? DateTime.now().difference(_chunkStartTime!)
        : Duration.zero;
    final total = _totalEstimatedDuration;
    final estimated = _basePositionOffset + elapsed;
    final clamped = _clampDuration(estimated, min: Duration.zero, max: total);
    state = state.copyWith(estimatedPosition: clamped);
  }

  /// Sum of [TtsChunk.estimatedDuration] for chunks 0..[index] (exclusive).
  Duration _estimateOffsetUpToChunk(int index) {
    if (_chunks.isEmpty || index <= 0) return Duration.zero;
    final end = index.clamp(0, _chunks.length);
    return _chunks
        .sublist(0, end)
        .fold(Duration.zero, (acc, c) => acc + c.estimatedDuration);
  }

  Duration get _totalEstimatedDuration =>
      _chunks.fold(Duration.zero, (acc, c) => acc + c.estimatedDuration);

  // ─── Private helpers ───────────────────────────────────────────────────────

  Duration _clampDuration(
    Duration value, {
    required Duration min,
    required Duration max,
  }) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _syncConfigFromRuntime() {
    if (!mounted) return;
    state = state.copyWith(
      language: _runtime.currentLanguage,
      config: state.config.copyWith(
        rate: _runtime.currentSynthesisRate,
        pitch: _runtime.currentPitch,
        languageCode: _runtime.currentLanguage,
      ),
    );
  }

  void _setPlaybackError(Object error, {required String language}) {
    if (!mounted) return;
    _stopPositionTimer();
    state = state.copyWith(
      status: TtsStatus.error,
      language: language,
      config: state.config.copyWith(languageCode: language),
      error: _describeError(error),
    );
  }

  String _describeError(Object error) {
    var message = error.toString().trim();
    for (final prefix in ['Bad state: ', 'Exception: ', 'Error: ']) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length);
        break;
      }
    }
    return message;
  }

  void _cancelSeekDebounce() {
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = null;
  }

  String _buildArticleId(
    String title,
    String text,
    String language,
    String category,
  ) {
    final digest = sha1
        .convert(utf8.encode('$title|$language|$category|$text'))
        .toString();
    return 'text_$digest';
  }

  String _inferLanguageFromChunks(List<TtsChunk> chunks) {
    final hasBanglaGlyph = chunks.any(
      (c) => RegExp(r'[\u0980-\u09FF]').hasMatch(c.text),
    );
    return hasBanglaGlyph ? 'bn-BD' : 'en-US';
  }

  TtsStatus _resolveStatus(
    TtsSessionState? sessionState,
    PlaybackState playbackState,
  ) {
    if (playbackState.processingState == AudioProcessingState.buffering ||
        playbackState.processingState == AudioProcessingState.loading) {
      return TtsStatus.buffering;
    }

    switch (sessionState) {
      case TtsSessionState.preparing:
      case TtsSessionState.chunking:
      case TtsSessionState.generating:
        return TtsStatus.loading;
      case TtsSessionState.buffering:
        return TtsStatus.buffering;
      case TtsSessionState.playing:
        return TtsStatus.playing;
      case TtsSessionState.paused:
        return TtsStatus.paused;
      case TtsSessionState.completed:
        return TtsStatus.completed;
      case TtsSessionState.stopped:
        return TtsStatus.stopped;
      case TtsSessionState.error:
        return TtsStatus.error;
      case TtsSessionState.idle:
      case TtsSessionState.recovering:
      default:
        return TtsStatus.idle;
    }
  }
}
