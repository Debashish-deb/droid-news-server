import 'dart:async';
import 'dart:io' show File;
import 'package:audio_service/audio_service.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/pipeline_orchestrator.dart';
import '../core/text_cleaner.dart';
import '../domain/models/speech_chunk.dart';
import '../domain/models/tts_session.dart';
import '../domain/models/tts_runtime_diagnostics.dart';
import '../domain/repositories/tts_repository.dart';
import '../engine/preloader/chunk_preloader.dart';
import 'tts_service.dart';
import 'audio_cache_manager.dart';
import 'tts_player_handler.dart';
import '../core/tts_analytics.dart';
import '../core/synthesis_circuit_breaker.dart';
import '../core/tts_performance_monitor.dart';
import 'tts_prosody_builder.dart';
import 'tts_sleep_timer.dart';
import 'tts_synthesis_queue.dart';
import 'tts_preference_keys.dart';
import '../../../../core/tts/shared/tts_voice_heuristics.dart';
import 'adaptive_speech_profile_store.dart';
import 'speech_delivery_intelligence.dart';

// ── Top-level isolate helper ──────────────────────────────────────────────────
//
// TextCleaner.clean() runs regex passes over the full article body.
// On a 5,000-word article this can block the main isolate for 50-150ms,
// dropping frames.  compute() offloads this to a worker isolate so the UI
// stays at 60fps.

Future<String> _cleanTextInIsolate(String raw) async =>
    compute(_cleanWorker, raw);

String _cleanWorker(String raw) => TextCleaner.clean(raw);

// ─────────────────────────────────────────────────────────────────────────────

class TtsManager {
  TtsManager({
    required TtsStorageRepository repository,
    required TtsAnalytics analytics,
    required SynthesisCircuitBreaker circuitBreaker,
    required TtsPerformanceMonitor performanceMonitor,
    required PipelineOrchestrator pipelineOrchestrator,
    required AudioCacheManager cacheManager,
    AdaptiveSpeechProfileStore? adaptiveSpeechProfileStore,
  }) : _repository = repository,
       _analytics = analytics,
       _circuitBreaker = circuitBreaker,
       _performanceMonitor = performanceMonitor,
       _pipelineOrchestrator = pipelineOrchestrator,
       _cacheManager = cacheManager,
       _adaptiveSpeechProfileStore =
           adaptiveSpeechProfileStore ?? AdaptiveSpeechProfileStore() {
    _ttsService = FlutterTtsAdapter();
    _preloader = ChunkPreloader(synthesizeChunk: _synthesizeChunkForPreloader);
    _sleepTimer = TtsSleepTimer(onSleepTimerExpired: stop);
  }

  @visibleForTesting
  TtsManager.createTestInstance({
    required TtsStorageRepository repository,
    required ChunkPreloader preloader,
    required AudioHandler audioHandler,
    required TtsService ttsService,
    required AudioCacheManager cacheManager,
    required PipelineOrchestrator pipelineOrchestrator,
    TtsAnalytics? analytics,
    AdaptiveSpeechProfileStore? adaptiveSpeechProfileStore,
  }) : _repository = repository,
       _preloader = preloader,
       _audioHandler = audioHandler,
       _ttsService = ttsService,
       _cacheManager = cacheManager,
       _pipelineOrchestrator = pipelineOrchestrator,
       _adaptiveSpeechProfileStore =
           adaptiveSpeechProfileStore ?? AdaptiveSpeechProfileStore(),
       _analytics = analytics ?? TtsAnalytics(),
       _circuitBreaker = SynthesisCircuitBreaker(
         analytics: analytics ?? TtsAnalytics(),
       ),
       _performanceMonitor = TtsPerformanceMonitor(
         analytics: analytics ?? TtsAnalytics(),
       ) {
    _sleepTimer = TtsSleepTimer(onSleepTimerExpired: stop);
  }

  static const Object _diagnosticsUnset = Object();

  // ── Dependencies ───────────────────────────────────────────────────────────
  final TtsStorageRepository _repository;
  final TtsAnalytics _analytics;
  final SynthesisCircuitBreaker _circuitBreaker;
  final TtsPerformanceMonitor _performanceMonitor;
  final PipelineOrchestrator _pipelineOrchestrator;
  final AudioCacheManager _cacheManager;
  final AdaptiveSpeechProfileStore _adaptiveSpeechProfileStore;
  late final ChunkPreloader _preloader;

  AudioHandler? _audioHandler;
  late TtsService _ttsService;

  // ── Session state ──────────────────────────────────────────────────────────
  TtsSession? _currentSession;
  List<SpeechChunk> _currentChunks = [];
  bool _isInitialized = false;
  Future<void>? _initFuture;
  Future<void> Function()? _lastReplayAction;
  final TtsSynthesisQueue _synthesisQueue = TtsSynthesisQueue();
  static const int _kQueuedChunkLookahead = 2;
  final Set<int> _pendingQueuedChunkIndices = <int>{};
  int _playbackQueueToken = 0;

  // Synthesis baseline tuned for natural voice; playback speed is still
  // controlled by the audio player.
  double _baseSynthesisRate = 0.42;
  double _baseSynthesisPitch = 1.0;
  double _playbackSpeed = 1.0;
  TtsPreset _currentPreset = TtsPreset.natural;
  TtsPreset _activePresetForSession = TtsPreset.natural;
  AdaptiveSpeechProfile _activeAdaptiveProfile = const AdaptiveSpeechProfile();
  String _currentArticleCategory = 'general';
  String _currentArticleLanguage = 'en';
  String _activeSynthesisProfileKey = '';

  /// Guard against the stop()→completion race.
  /// Set to true the moment stop() begins; cleared when new playback starts.
  bool _isStopping = false;

  // ── Optional feed/article navigation hooks ───────────────────────────────
  Future<void> Function()? _onPreviousFeedArticle;
  Future<void> Function()? _onNextFeedArticle;
  bool Function()? _canPreviousFeedArticle;
  bool Function()? _canNextFeedArticle;

  // ── Sleep timer ───────────────────────────────────────────────────────────
  late final TtsSleepTimer _sleepTimer;

  // ── Streams ────────────────────────────────────────────────────────────────
  final _chunkIndexController = StreamController<int>.broadcast();
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;

  final _chunkController = StreamController<SpeechChunk?>.broadcast();
  Stream<SpeechChunk?> get currentChunk => _chunkController.stream;

  final _sessionController = StreamController<TtsSession?>.broadcast();
  Stream<TtsSession?> get sessionStream => _sessionController.stream;

  final _diagnosticsController =
      StreamController<TtsRuntimeDiagnostics>.broadcast();
  TtsRuntimeDiagnostics _currentDiagnostics = const TtsRuntimeDiagnostics();
  Stream<TtsRuntimeDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;
  TtsRuntimeDiagnostics get diagnostics => _currentDiagnostics;

  /// Remaining sleep time; null when no timer is active.
  Stream<Duration?> get sleepTimerRemaining => _sleepTimer.sleepTimerRemaining;

  double get currentSpeed => _playbackSpeed;
  TtsPreset get currentPreset => _currentPreset;
  double get currentPitch => _baseSynthesisPitch;
  double get currentSynthesisRate => _baseSynthesisRate;
  String get currentLanguage => _currentArticleLanguage;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _updateDiagnostics(
      phase: TtsRuntimePhase.initializing,
      message: 'Preparing audio engine',
      lastError: null,
    );
    _initFuture = _initCore();
    try {
      await _initFuture;
    } finally {
      if (!_isInitialized) {
        _initFuture = null;
      }
    }
  }

  Future<void> _initCore() async {
    try {
      // Use the factory that wires onChunkCompleted at construction time,
      // eliminating the nullable-callback race from the original code.
      _audioHandler ??= await AudioService.init(
        builder: () => TtsPlayerHandler(
          onChunkCompleted: _onChunkCompleted,
          onChunkStarted: _onChunkStarted,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.bd.bdnewsreader.tts',
          androidNotificationChannelName: 'News Reading',
          androidNotificationOngoing: true,
        ),
      );

      await _ttsService.init();
      await _ttsService.setRate(_baseSynthesisRate);
      await _ttsService.setPitch(_baseSynthesisPitch);
      await _restoreAudioPreferences();

      final lastSession = await _repository.getLastSession();
      if (lastSession != null && lastSession.isResumable) {
        debugPrint(
          '[TtsManager] Discarded stale resumable session: ${lastSession.articleTitle}',
        );
      }

      _isInitialized = true;
      _updateDiagnostics(
        phase: TtsRuntimePhase.idle,
        message: 'TTS engine ready',
        lastError: null,
      );
      debugPrint('[TtsManager] Initialized successfully.');
    } catch (e, st) {
      debugPrint('[TtsManager] Init error: $e\n$st');
      final message = 'Init failed: $e';
      await _analytics.trackSynthesisError(
        message,
        Duration.zero,
        stackTrace: st,
        context: <String, Object?>{
          'phase': 'initializing',
          'article_id': _currentSession?.articleId,
        },
      );
      _isInitialized = false;
      _updateDiagnostics(
        phase: TtsRuntimePhase.error,
        message: 'Unable to initialize TTS',
        lastError: message,
      );
      throw StateError(message);
    }
  }

  // ── Chunk completion callback (called from TtsPlayerHandler) ────────────────

  /// This is called by [TtsPlayerHandler] when a chunk finishes playing.
  /// It is wired at construction time, so there is no nullable-callback window.
  void _onChunkCompleted() {
    if (_isStopping) {
      debugPrint('[TtsManager] Completion ignored — stop in progress.');
      return;
    }
    // Run next-chunk logic asynchronously so we don't block the audio callback
    _advanceToNextChunk();
  }

  void _onChunkStarted(int chunkIndex) {
    if (_isStopping || _currentSession == null) return;
    if (chunkIndex < 0 || chunkIndex >= _currentChunks.length) return;

    _updateSessionIndex(chunkIndex);
    _updateDiagnostics(
      phase: TtsRuntimePhase.playing,
      message: 'Playing ${_chunkLabel(chunkIndex)}',
      chunkIndex: chunkIndex,
      totalChunks: _currentChunks.length,
      lastError: null,
    );
    unawaited(_queueUpcomingChunks(chunkIndex, token: _playbackQueueToken));
  }

  Future<void> _advanceToNextChunk() async {
    if (_currentSession == null || _isStopping) return;

    final currentIdx = _currentSession!.currentChunkIndex;

    if (currentIdx < _currentChunks.length - 1) {
      final nextIndex = currentIdx + 1;
      _updateSessionIndex(nextIndex);
      // No artificial delay — the watchdog and audio pipeline handle timing
      await _playChunk(nextIndex);
    } else {
      debugPrint('[TtsManager] Article completed.');
      _setCurrentSession(
        _currentSession!.copyWith(state: TtsSessionState.completed),
      );
      await _repository.saveSession(_currentSession!);
      _updateDiagnostics(
        phase: TtsRuntimePhase.idle,
        message: 'Article finished',
        chunkIndex: _currentSession!.currentChunkIndex,
        totalChunks: _currentChunks.length,
        lastError: null,
      );
      _chunkController.add(null);
      _chunkIndexController.add(-1);
      await _audioHandler?.stop();
    }
  }

  // ── Accessors ──────────────────────────────────────────────────────────────

  Stream<PlaybackState> get playbackState =>
      _audioHandler?.playbackState ?? Stream.value(PlaybackState());

  Stream<MediaItem?> get mediaItem =>
      _audioHandler?.mediaItem ?? Stream.value(null);

  /// Position stream from the underlying player for seekable UI.
  Stream<Duration> get positionStream {
    final handler = _audioHandler;
    if (handler is TtsPlayerHandler) return handler.positionStream;
    return const Stream.empty();
  }

  /// Duration stream from the underlying player.
  Stream<Duration> get durationStream {
    final handler = _audioHandler;
    if (handler is TtsPlayerHandler) return handler.durationStream;
    return const Stream.empty();
  }

  int get totalChunks => _currentChunks.length;
  int get currentChunkNumber => (_currentSession?.currentChunkIndex ?? 0) + 1;
  String get currentArticleTitle => _currentSession?.articleTitle ?? '';
  TtsSession? get currentSession => _currentSession;
  bool get canGoPreviousFeedArticle => _canPreviousFeedArticle?.call() ?? false;
  bool get canGoNextFeedArticle => _canNextFeedArticle?.call() ?? false;

  void configureFeedNavigation({
    Future<void> Function()? onPreviousFeedArticle,
    Future<void> Function()? onNextFeedArticle,
    bool Function()? canPreviousFeedArticle,
    bool Function()? canNextFeedArticle,
  }) {
    _onPreviousFeedArticle = onPreviousFeedArticle;
    _onNextFeedArticle = onNextFeedArticle;
    _canPreviousFeedArticle = canPreviousFeedArticle;
    _canNextFeedArticle = canNextFeedArticle;
  }

  void clearFeedNavigation() {
    _onPreviousFeedArticle = null;
    _onNextFeedArticle = null;
    _canPreviousFeedArticle = null;
    _canNextFeedArticle = null;
  }

  Duration get estimatedTimeRemaining {
    if (_currentChunks.isEmpty) return Duration.zero;
    final idx = _currentSession?.currentChunkIndex ?? 0;
    if (idx >= _currentChunks.length) return Duration.zero;
    int chars = 0;
    for (int i = idx; i < _currentChunks.length; i++) {
      chars += _currentChunks[i].text.length;
    }
    // 12.5 chars/s at 1× speed; adjust for user rate
    final rate = math.max(0.1, _playbackSpeed);
    return Duration(seconds: (chars / (12.5 * rate)).ceil());
  }

  // ── speakArticle ───────────────────────────────────────────────────────────

  Future<void> speakArticle(
    String articleId,
    String title,
    String content, {
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
  }) async {
    _lastReplayAction = () => speakArticle(
      articleId,
      title,
      content,
      language: language,
      category: category,
      author: author,
      imageSource: imageSource,
    );
    if (!_isInitialized) {
      await init();
    }
    final normalizedLanguage = _normalizedLanguageCode(language);
    final normalizedCategory = SpeechDeliveryIntelligence.normalizeCategory(
      category,
    );
    _currentArticleLanguage = normalizedLanguage;
    _currentArticleCategory = normalizedCategory;

    // Reset the circuit breaker at the start of every new article so that
    // a previous failure does not permanently block synthesis for this session.
    _circuitBreaker.reset();

    _activeAdaptiveProfile = await _adaptiveSpeechProfileStore.resolve(
      language: normalizedLanguage,
      category: normalizedCategory,
    );
    _activePresetForSession = _resolvePresetForSession(
      _activeAdaptiveProfile.preferredPresetName,
    );
    _activeSynthesisProfileKey = _buildActiveSynthesisProfileKey(
      language: normalizedLanguage,
      category: normalizedCategory,
    );
    _updateDiagnostics(
      phase: TtsRuntimePhase.preparing,
      message: 'Preparing article audio',
      lastError: null,
      articleId: articleId,
      articleTitle: title,
      chunkIndex: 0,
      totalChunks: 0,
      synthesisStrategy: 'pipeline',
      usedCachedAudio: null,
    );

    await _safeSetLanguage(normalizedLanguage);
    await _ensureHumanLikeVoiceForLanguage(normalizedLanguage);

    // ── Same-article guard ────────────────────────────────────────────────
    // If this exact article is already playing or paused, just toggle rather
    // than tearing down and re-processing the whole session.
    if (_currentSession?.articleId == articleId &&
        _currentSession?.state != TtsSessionState.stopped &&
        _currentSession?.state != TtsSessionState.completed &&
        _currentSession?.state != TtsSessionState.error) {
      final state = _audioHandler?.playbackState.value;
      if (state?.playing == true) {
        await pause();
      } else {
        await resume();
      }
      return;
    }

    // Stop any current session cleanly before starting a new one
    if (_currentSession != null) {
      await stop();
    }

    await _analytics.trackPlaybackStart(articleId);

    // ── Text cleaning in isolate (non-blocking) ───────────────────────────
    final cleanedContent = await _cleanTextInIsolate(content);
    if (cleanedContent.isEmpty) {
      debugPrint('[TtsManager] Article empty after cleaning.');
      throw StateError('Article content is empty after cleaning.');
    }

    final result = await _pipelineOrchestrator.processArticle(
      articleId: articleId,
      title: title,
      content: cleanedContent,
      language: normalizedLanguage,
      category: normalizedCategory,
      author: author,
      imageSource: imageSource,
      contentIsCleaned: true,
    );

    if (!result.success || result.session == null) {
      debugPrint('[TtsManager] Pipeline failed: ${result.error}');
      throw StateError(result.error ?? 'Unable to prepare article audio.');
    }

    _isStopping = false;
    _setCurrentSession(
      result.session!.copyWith(
        state: TtsSessionState.playing,
        articleCategory: normalizedCategory,
        articleLanguage: normalizedLanguage,
      ),
    );
    _currentChunks = result.chunks!
        .map(
          (chunk) => chunk.copyWith(
            articleCategory: normalizedCategory,
            synthesisProfileKey: _activeSynthesisProfileKey,
          ),
        )
        .toList(growable: false);

    await _repository.saveSession(_currentSession!);
    debugPrint(
      '[TtsManager] Session created. Chunks: ${_currentChunks.length}',
    );

    if (_currentChunks.isEmpty) {
      throw StateError('No playable speech chunks were generated.');
    }

    _chunkIndexController.add(0);
    await _playChunk(0);
  }

  Future<void> speakPreparedChunks(
    String articleId,
    String title,
    List<SpeechChunk> chunks, {
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
  }) async {
    if (chunks.isEmpty) return;
    _lastReplayAction = () => speakPreparedChunks(
      articleId,
      title,
      chunks,
      language: language,
      category: category,
      author: author,
      imageSource: imageSource,
    );
    if (!_isInitialized) {
      await init();
    }

    final normalizedLanguage = _normalizedLanguageCode(language);
    final normalizedCategory = SpeechDeliveryIntelligence.normalizeCategory(
      category,
    );
    _currentArticleLanguage = normalizedLanguage;
    _currentArticleCategory = normalizedCategory;

    // Reset the circuit breaker at the start of every new article so that
    // a previous failure does not permanently block synthesis for this session.
    _circuitBreaker.reset();

    _activeAdaptiveProfile = await _adaptiveSpeechProfileStore.resolve(
      language: normalizedLanguage,
      category: normalizedCategory,
    );
    _activePresetForSession = _resolvePresetForSession(
      _activeAdaptiveProfile.preferredPresetName,
    );
    _activeSynthesisProfileKey = _buildActiveSynthesisProfileKey(
      language: normalizedLanguage,
      category: normalizedCategory,
    );
    _updateDiagnostics(
      phase: TtsRuntimePhase.preparing,
      message: 'Preparing reader audio',
      lastError: null,
      articleId: articleId,
      articleTitle: title,
      chunkIndex: 0,
      totalChunks: chunks.length,
      synthesisStrategy: 'prepared_chunks',
      usedCachedAudio: null,
    );

    await _safeSetLanguage(normalizedLanguage);
    await _ensureHumanLikeVoiceForLanguage(normalizedLanguage);

    if (_currentSession?.articleId == articleId &&
        _currentSession?.state != TtsSessionState.stopped &&
        _currentSession?.state != TtsSessionState.completed &&
        _currentSession?.state != TtsSessionState.error) {
      final state = _audioHandler?.playbackState.value;
      if (state?.playing == true) {
        await pause();
      } else {
        await resume();
      }
      return;
    }

    if (_currentSession != null) {
      await stop();
    }

    await _analytics.trackPlaybackStart(articleId);

    _isStopping = false;
    _setCurrentSession(
      TtsSession.create(
        articleId: articleId,
        articleTitle: title,
        articleCategory: normalizedCategory,
        articleLanguage: normalizedLanguage,
      ).copyWith(totalChunks: chunks.length, state: TtsSessionState.playing),
    );
    _currentChunks = chunks
        .map(
          (chunk) => chunk.copyWith(
            articleCategory: normalizedCategory,
            language: normalizedLanguage,
            synthesisProfileKey: _activeSynthesisProfileKey,
          ),
        )
        .toList(growable: false);

    await _repository.saveSession(_currentSession!);
    _chunkIndexController.add(0);
    _chunkController.add(_currentChunks.first);
    await _playChunk(0);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> nextChunk() async {
    if (_currentSession == null || _isStopping) return;
    final next = _currentSession!.currentChunkIndex + 1;
    if (next < _currentChunks.length) {
      _updateSessionIndex(next);
      await _playChunk(next);
    }
  }

  Future<void> previousChunk() async {
    if (_currentSession == null) return;
    final prev = _currentSession!.currentChunkIndex - 1;
    if (prev >= 0) {
      _updateSessionIndex(prev);
      await _playChunk(prev);
    }
  }

  /// Previous button behavior used by player UIs:
  /// 1) navigate to previous feed article when available
  /// 2) otherwise go to previous chunk in current article
  Future<void> previous() async {
    if (canGoPreviousFeedArticle && _onPreviousFeedArticle != null) {
      await _onPreviousFeedArticle!.call();
      return;
    }
    await previousChunk();
  }

  /// Next button behavior used by player UIs:
  /// 1) navigate to next feed article when available
  /// 2) otherwise go to next chunk in current article
  Future<void> next() async {
    if (canGoNextFeedArticle && _onNextFeedArticle != null) {
      await _onNextFeedArticle!.call();
      return;
    }
    await nextChunk();
  }

  /// Seek within the current chunk (e.g., ±15s buttons in the full player).
  Future<void> seekRelative(Duration offset) async {
    final handler = _audioHandler;
    if (handler is TtsPlayerHandler) {
      await handler.seekRelative(offset);
    }
  }

  /// Jump to a specific chunk index directly (for progress-bar tap).
  Future<void> seekToChunk(int index) async {
    if (index < 0 || index >= _currentChunks.length) return;
    _updateSessionIndex(index);
    await _playChunk(index);
  }

  void _updateSessionIndex(int index) {
    if (_currentSession == null) return;
    if (_currentSession!.currentChunkIndex == index) {
      if (index >= 0 && index < _currentChunks.length) {
        _chunkController.add(_currentChunks[index]);
      }
      return;
    }
    _setCurrentSession(_currentSession!.copyWith(currentChunkIndex: index));
    unawaited(_repository.saveSession(_currentSession!));
    _chunkIndexController.add(index);
    if (index >= 0 && index < _currentChunks.length) {
      _chunkController.add(_currentChunks[index]);
    } else {
      _chunkController.add(null);
    }
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  Future<void> pause() async {
    if (_currentSession != null) {
      _setCurrentSession(
        _currentSession!.copyWith(state: TtsSessionState.paused),
      );
      unawaited(_repository.saveSession(_currentSession!));
    }
    await _audioHandler?.pause();
    // Stop direct TTS fallback if active
    await _ttsService.stop();
    _updateDiagnostics(
      phase: TtsRuntimePhase.paused,
      message: 'Playback paused',
      lastError: null,
    );
  }

  Future<void> resume() async {
    if (_currentSession == null) return;

    _setCurrentSession(
      _currentSession!.copyWith(state: TtsSessionState.playing),
    );
    unawaited(_repository.saveSession(_currentSession!));

    // ── Fixed resume logic ─────────────────────────────────────────────────
    // The original always fell through to _playChunk which re-synthesized and
    // restarted the chunk from byte 0.
    //
    // Correct behaviour:
    //   1. Try audioHandler.play() — resumes just_audio from where it paused.
    //   2. Only fall back to _playChunk if the player is in idle/completed
    //      state (meaning the source was lost, e.g. after process death).
    final handler = _audioHandler;
    if (handler != null) {
      final playbackState = handler.playbackState.value;
      final ps = playbackState.processingState;
      final isPaused =
          ps == AudioProcessingState.ready && !playbackState.playing;

      if (isPaused) {
        // Resume from mid-stream — no re-synthesis needed
        await handler.play();
        _updateDiagnostics(
          phase: TtsRuntimePhase.playing,
          message: 'Playback resumed',
          lastError: null,
        );
        return;
      }
      if (playbackState.playing ||
          ps == AudioProcessingState.loading ||
          ps == AudioProcessingState.buffering) {
        _updateDiagnostics(
          phase: TtsRuntimePhase.playing,
          message: 'Playback already active',
          lastError: null,
        );
        return;
      }
    }

    // Source was lost or the player is no longer in a resumable state
    // (for example after lifecycle churn or a platform-side reset).
    final idx = _currentSession!.currentChunkIndex;
    if (idx >= 0 && idx < _currentChunks.length) {
      await _playChunk(idx);
      return;
    }

    throw StateError('No playable chunk is available to resume.');
  }

  Future<void> retry() async {
    _isStopping = false;
    _updateDiagnostics(
      phase: TtsRuntimePhase.preparing,
      message: 'Retrying playback',
      lastError: null,
    );

    if (_currentSession != null && _currentChunks.isNotEmpty) {
      final index = _currentSession!.currentChunkIndex.clamp(
        0,
        _currentChunks.length - 1,
      );
      _setCurrentSession(
        _currentSession!.copyWith(
          state: TtsSessionState.playing,
          errorMessage: null,
        ),
      );
      await _repository.saveSession(_currentSession!);
      await _audioHandler?.stop();
      await _ttsService.stop();
      await _playChunk(index);
      return;
    }

    final replay = _lastReplayAction;
    if (replay != null) {
      await replay();
      return;
    }

    throw StateError('No previous TTS request is available to retry.');
  }

  Future<void> setSpeed(double speed) async {
    final target = speed.clamp(0.5, 2.0).toDouble();
    _playbackSpeed = target;
    await _audioHandler?.setSpeed(target);
    unawaited(_persistDouble(TtsPreferenceKeys.playbackSpeed, target));
    if (_currentSession != null) {
      unawaited(
        _adaptiveSpeechProfileStore.recordPlaybackPaceCorrection(
          language: _currentArticleLanguage,
          category: _currentArticleCategory,
          playbackSpeed: target,
        ),
      );
      _activeAdaptiveProfile = _activeAdaptiveProfile.copyWith(
        rateBias: ((target - 1.0) * 0.06).clamp(-0.035, 0.035).toDouble(),
        correctionCount: _activeAdaptiveProfile.correctionCount + 1,
      );
      _activeSynthesisProfileKey = _buildActiveSynthesisProfileKey(
        language: _currentArticleLanguage,
        category: _currentArticleCategory,
      );
      _retagChunksForActiveSpeechProfile();
    }
  }

  Future<void> setPitch(double pitch) async {
    _baseSynthesisPitch = pitch.clamp(0.9, 1.08).toDouble();
    await _ttsService.setPitch(_baseSynthesisPitch);
    unawaited(_persistDouble(TtsPreferenceKeys.pitch, _baseSynthesisPitch));
    if (_currentSession != null) {
      unawaited(
        _adaptiveSpeechProfileStore.recordPitchCorrection(
          language: _currentArticleLanguage,
          category: _currentArticleCategory,
          pitch: _baseSynthesisPitch,
        ),
      );
      _activeAdaptiveProfile = _activeAdaptiveProfile.copyWith(
        pitchBias: (_baseSynthesisPitch - 1.0).clamp(-0.04, 0.04).toDouble(),
        correctionCount: _activeAdaptiveProfile.correctionCount + 1,
      );
      _activeSynthesisProfileKey = _buildActiveSynthesisProfileKey(
        language: _currentArticleLanguage,
        category: _currentArticleCategory,
      );
      _retagChunksForActiveSpeechProfile();
    }
  }

  Future<void> setVolume(double volume) async {
    final handler = _audioHandler;
    if (handler is TtsPlayerHandler) {
      final target = volume.clamp(0.0, 1.0).toDouble();
      await handler.setVolume(target);
      unawaited(_persistDouble(TtsPreferenceKeys.volume, target));
    }
  }

  Future<void> setRate(double rate) async {
    _baseSynthesisRate = rate.clamp(0.3, 0.6).toDouble();
    await _ttsService.setRate(_baseSynthesisRate);
    unawaited(
      _persistDouble(TtsPreferenceKeys.synthesisRate, _baseSynthesisRate),
    );
  }

  Future<void> setPreset(TtsPreset preset) async {
    _currentPreset = preset;
    _activePresetForSession = preset;
    unawaited(_persistString(TtsPreferenceKeys.preset, preset.name));
    if (_currentSession != null) {
      unawaited(
        _adaptiveSpeechProfileStore.recordPresetCorrection(
          language: _currentArticleLanguage,
          category: _currentArticleCategory,
          presetName: preset.name,
        ),
      );
      _activeAdaptiveProfile = _activeAdaptiveProfile.copyWith(
        preferredPresetName: preset.name,
        correctionCount: _activeAdaptiveProfile.correctionCount + 1,
      );
      _activeSynthesisProfileKey = _buildActiveSynthesisProfileKey(
        language: _currentArticleLanguage,
        category: _currentArticleCategory,
      );
      _retagChunksForActiveSpeechProfile();
    }
  }

  Future<void> stop() async {
    // Raise the flag FIRST so any pending _onChunkCompleted calls are ignored
    _isStopping = true;
    _playbackQueueToken += 1;
    _pendingQueuedChunkIndices.clear();
    _sleepTimer.cancelSleepTimer();

    // Clear the replay action so a subsequent retry() doesn't re-play a
    // session that was explicitly stopped by the user.
    _lastReplayAction = null;

    if (_currentSession != null) {
      _setCurrentSession(
        _currentSession!.copyWith(state: TtsSessionState.stopped),
      );
      unawaited(_repository.saveSession(_currentSession!));
    }

    _chunkController.add(null);
    _chunkIndexController.add(-1); // Hides the mini player

    await _audioHandler?.stop();
    await _ttsService.stop();

    _preloader.clear();
    _updateDiagnostics(
      phase: TtsRuntimePhase.stopped,
      message: 'Playback stopped',
      lastError: null,
    );
  }

  // ── Sleep timer ────────────────────────────────────────────────────────────

  void setSleepTimer(Duration duration) {
    _sleepTimer.setSleepTimer(duration);
  }

  Duration? get sleepTimerRemaining_ => _sleepTimer.sleepTimerRemainingValue;

  // ── Voice ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, String>>> getAvailableVoices() =>
      _ttsService.getVoices();

  Future<void> setVoice(String name, String locale) async {
    final normalizedLocale = _normalizedLanguageCode(locale);
    final availableVoices = await getAvailableVoices();
    final preferredVoice = availableVoices.firstWhere(
      (voice) => voice['name'] == name && voice['locale'] == locale,
      orElse: () =>
          TtsVoiceHeuristics.pickBestVoiceMap(
            availableVoices,
            preferredLanguageCode: normalizedLocale,
          ) ??
          const <String, String>{},
    );
    if (preferredVoice.isEmpty) return;

    final resolvedName = preferredVoice['name']!;
    final resolvedLocale = preferredVoice['locale']!;
    await _ttsService.setVoice(resolvedName, resolvedLocale);
    await _safeSetLanguage(resolvedLocale);
    unawaited(_persistString(TtsPreferenceKeys.voiceName, resolvedName));
    unawaited(_persistString(TtsPreferenceKeys.voiceLocale, resolvedLocale));
  }

  // ── Internal playback ──────────────────────────────────────────────────────

  Future<void> _playChunk(int index) async {
    if (index >= _currentChunks.length || _isStopping) return;

    final chunk = _currentChunks[index];
    _chunkController.add(chunk);
    _updateDiagnostics(
      phase: TtsRuntimePhase.synthesizing,
      message: 'Preparing ${_chunkLabel(index)}',
      articleId: _currentSession?.articleId,
      articleTitle: _currentSession?.articleTitle,
      chunkIndex: index,
      totalChunks: _currentChunks.length,
      lastError: null,
      usedCachedAudio: null,
    );

    String? audioPath;
    bool usedCachedAudio = false;

    // Cache lookup
    audioPath = await _resolveCachedAudioPath(chunk);
    if (audioPath != null) {
      usedCachedAudio = true;
      await _analytics.trackCacheHit(true);
    } else {
      await _analytics.trackCacheHit(false);
      audioPath = await _synthesizeChunk(chunk);
    }

    if (audioPath == null) {
      final synthesisDebug = _ttsService.lastSynthesisDebugInfo;
      final failureMessage = [
        'Unable to synthesize audio for ${_chunkLabel(index)}.',
        if ((synthesisDebug.message ?? '').trim().isNotEmpty)
          synthesisDebug.message!,
      ].join(' ');
      debugPrint(
        '[TtsManager] Synthesis null for chunk $index; marking error.',
      );
      await _analytics.trackSynthesisError(
        failureMessage,
        Duration.zero,
        context: <String, Object?>{
          'phase': 'chunk_synthesis',
          'chunk_index': index,
          'article_id': _currentSession?.articleId,
          'strategy': synthesisDebug.strategy,
        },
      );
      if (_currentSession != null) {
        _setCurrentSession(_currentSession!.markError(failureMessage));
        await _repository.saveSession(_currentSession!);
      }
      _updateDiagnostics(
        phase: TtsRuntimePhase.error,
        message: 'Synthesis failed',
        lastError: failureMessage,
        chunkIndex: index,
        totalChunks: _currentChunks.length,
        requestedOutputPath: synthesisDebug.requestedPath,
        resolvedOutputPath: synthesisDebug.resolvedPath,
        synthesisStrategy: synthesisDebug.strategy,
        usedCachedAudio: false,
      );
      _chunkController.add(null);
      _chunkIndexController.add(-1);
      await _audioHandler?.stop();
      return;
    }

    // Abort if session changed while we were synthesizing
    if (_isStopping ||
        _currentSession == null ||
        _currentSession!.state == TtsSessionState.stopped ||
        _currentSession!.currentChunkIndex != index) {
      debugPrint(
        '[TtsManager] Aborting play for chunk $index (state changed).',
      );
      return;
    }

    final mediaItem = MediaItem(
      id: audioPath,
      album: 'Reading',
      title: _currentSession?.articleTitle ?? 'Article',
      artist: 'News Reader',
      extras: _mediaExtrasForChunk(index),
    );

    try {
      final handler = _audioHandler;
      if (handler is ChunkQueueAudioHandler) {
        final queueHandler = handler as ChunkQueueAudioHandler;
        _playbackQueueToken += 1;
        final queueToken = _playbackQueueToken;
        _pendingQueuedChunkIndices.clear();
        await queueHandler.playQueuedChunk(
          Uri.file(audioPath),
          chunkIndex: index,
          extras: mediaItem.extras,
        );
        unawaited(_queueUpcomingChunks(index, token: queueToken));
      } else {
        await _audioHandler!.playFromUri(Uri.file(audioPath), mediaItem.extras);
      }
    } catch (error, stackTrace) {
      final message =
          'Unable to start playback for ${_chunkLabel(index)}: $error';
      await _analytics.trackSynthesisError(
        message,
        Duration.zero,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'phase': 'chunk_playback',
          'chunk_index': index,
          'article_id': _currentSession?.articleId,
        },
      );
      if (_currentSession != null) {
        _setCurrentSession(_currentSession!.markError(message));
        await _repository.saveSession(_currentSession!);
      }
      _updateDiagnostics(
        phase: TtsRuntimePhase.error,
        message: 'Playback failed',
        lastError: message,
        chunkIndex: index,
        totalChunks: _currentChunks.length,
        resolvedOutputPath: audioPath,
        synthesisStrategy: usedCachedAudio ? 'cache' : 'synthesized',
        usedCachedAudio: usedCachedAudio,
      );
      _chunkController.add(null);
      _chunkIndexController.add(-1);
      await _audioHandler?.stop();
      return;
    }
    _updateDiagnostics(
      phase: TtsRuntimePhase.playing,
      message: 'Playing ${_chunkLabel(index)}',
      chunkIndex: index,
      totalChunks: _currentChunks.length,
      resolvedOutputPath: audioPath,
      synthesisStrategy: usedCachedAudio
          ? 'cache'
          : _ttsService.lastSynthesisDebugInfo.strategy,
      usedCachedAudio: usedCachedAudio,
      lastError: null,
    );
    final handler = _audioHandler;
    if (handler is! ChunkQueueAudioHandler) {
      _preloader.clearOldPreloads(index);
      unawaited(
        _preloader.preloadAhead(allChunks: _currentChunks, currentIndex: index),
      );
    }
  }

  Future<void> _queueUpcomingChunks(
    int currentIndex, {
    required int token,
  }) async {
    final handler = _audioHandler;
    if (handler is! ChunkQueueAudioHandler) return;
    final queueHandler = handler as ChunkQueueAudioHandler;
    if (_isStopping || _currentSession == null) return;

    final articleId = _currentSession!.articleId;
    final maxIndex = math.min(
      currentIndex + _kQueuedChunkLookahead,
      _currentChunks.length - 1,
    );

    for (int nextIndex = currentIndex + 1; nextIndex <= maxIndex; nextIndex++) {
      if (_isStopping ||
          token != _playbackQueueToken ||
          _currentSession?.articleId != articleId) {
        return;
      }
      if (queueHandler.queuedChunkIndices.contains(nextIndex) ||
          _pendingQueuedChunkIndices.contains(nextIndex)) {
        continue;
      }

      _pendingQueuedChunkIndices.add(nextIndex);
      try {
        final nextChunk = _currentChunks[nextIndex];
        final audioPath = await _resolveUpcomingChunkAudioPath(nextChunk);
        if (audioPath == null ||
            _isStopping ||
            token != _playbackQueueToken ||
            _currentSession?.articleId != articleId) {
          return;
        }

        await queueHandler.appendQueuedChunk(
          Uri.file(audioPath),
          chunkIndex: nextIndex,
          extras: _mediaExtrasForChunk(nextIndex),
        );
      } finally {
        _pendingQueuedChunkIndices.remove(nextIndex);
      }
    }
  }

  Future<String?> _resolveUpcomingChunkAudioPath(SpeechChunk chunk) async {
    final preloadedPath = _preloader.getPreloadedPath(chunk.id);
    if (preloadedPath != null && await _cacheManager.isValid(preloadedPath)) {
      return preloadedPath;
    }

    final cachedPath = await _resolveCachedAudioPath(chunk);
    if (cachedPath != null) return cachedPath;

    return _synthesizeChunk(chunk);
  }

  Map<String, dynamic> _mediaExtrasForChunk(int index) {
    return <String, dynamic>{
      'album': 'Reading',
      'chunkIndex': index,
      'totalChunks': _currentChunks.length,
      'articleId': _currentSession?.articleId,
      'title': _currentSession?.articleTitle ?? 'Article',
      'artist': 'News Reader',
    };
  }

  Future<String?> _synthesizeChunkForPreloader(SpeechChunk chunk) async {
    final cachedPath = await _resolveCachedAudioPath(chunk);
    if (cachedPath != null) return cachedPath;
    return _synthesizeChunk(chunk);
  }

  Future<String?> _resolveCachedAudioPath(SpeechChunk chunk) async {
    final cachedChunk = await _repository.getCachedChunk(chunk);
    final audioPath = cachedChunk?.audioPath;
    if (audioPath == null) return null;

    if (await _cacheManager.isValid(audioPath)) {
      return audioPath;
    }

    debugPrint(
      '[TtsManager] Cached audio missing or invalid for chunk ${chunk.id}; clearing stale cache entry.',
    );
    try {
      await _repository.deleteCachedChunk(chunk.textHash);
    } catch (error) {
      debugPrint('[TtsManager] Failed to clear stale cache entry: $error');
    }
    return null;
  }

  Future<String?> _synthesizeChunk(SpeechChunk chunk) async {
    return _synthesisQueue.runLocked(() async {
      try {
        final articleId = _currentSession?.articleId ?? 'unknown';
        return await _synthesizeWithRetry(chunk, articleId, chunk.id);
      } catch (e, st) {
        debugPrint('[TtsManager] Error synthesizing chunk: $e');
        await _analytics.trackSynthesisError(
          'Unhandled synthesis failure: $e',
          Duration.zero,
          stackTrace: st,
          context: <String, Object?>{
            'phase': 'synthesis_queue',
            'article_id': _currentSession?.articleId,
            'chunk_index': chunk.id,
          },
        );
        return null;
      }
    });
  }

  Future<String?> _synthesizeWithRetry(
    SpeechChunk chunk,
    String articleId,
    int index, {
    int maxAttempts = 3,
  }) async {
    final effectiveBaseRate =
        (_baseSynthesisRate + _activeAdaptiveProfile.rateBias)
            .clamp(0.34, 0.58)
            .toDouble();
    final effectiveBasePitch =
        (_baseSynthesisPitch + _activeAdaptiveProfile.pitchBias)
            .clamp(0.9, 1.08)
            .toDouble();
    final prosody = TtsProsodyBuilder.buildChunkProsody(
      chunk: chunk,
      baseSynthesisRate: effectiveBaseRate,
      baseSynthesisPitch: effectiveBasePitch,
      preset: _activePresetForSession,
    );
    final safeId = articleId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final profileId = chunk.synthesisProfileKey.isEmpty
        ? 'default'
        : chunk.synthesisProfileKey.hashCode.abs().toRadixString(16);
    final fileName = '${safeId}_${profileId}_$index.wav';

    int attempt = 0;
    Duration delay = const Duration(milliseconds: 500);

    while (attempt < maxAttempts) {
      if (_isStopping ||
          _currentSession == null ||
          _currentSession!.articleId != articleId ||
          _currentSession!.state == TtsSessionState.stopped) {
        debugPrint('[TtsManager] Synthesis aborted for $index');
        return null;
      }

      attempt++;
      try {
        final tempPath = p.join(await _getTempDir(), fileName);
        final sw = Stopwatch()..start();

        await _ttsService.setRate(prosody.rate);
        await _ttsService.setPitch(prosody.pitch);

        final resultPath = await _circuitBreaker.execute(
          () => _ttsService.synthesizeToFile(prosody.text, tempPath),
        );

        sw.stop();
        _performanceMonitor.recordLatency(sw.elapsed);

        if (resultPath != null) {
          final file = File(resultPath);
          if (await file.exists()) {
            final size = await file.length();
            if (size > 0) {
              final bytes = await file.readAsBytes();
              final audioPath = await _cacheManager.saveAudio(fileName, bytes);
              try {
                await file.delete();
              } catch (_) {}
              await _repository.cacheChunk(chunk, audioPath);
              return audioPath;
            } else {
              debugPrint(
                '[TtsManager] Synthesized file is 0 bytes (attempt $attempt)',
              );
              try {
                await file.delete();
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('[TtsManager] Synthesis attempt $attempt failed: $e');
        await _analytics.trackSynthesisError(
          'Attempt $attempt: $e',
          Duration.zero,
          context: <String, Object?>{
            'phase': 'synthesis_attempt',
            'attempt': attempt,
            'article_id': articleId,
            'chunk_index': index,
            'strategy': _ttsService.lastSynthesisDebugInfo.strategy,
          },
        );

        if (attempt >= maxAttempts) {
          debugPrint(
            '[TtsManager] All attempts exhausted; failing explicitly.',
          );
          await _analytics.trackSynthesisError(
            'All synthesis attempts failed for $articleId chunk $index',
            Duration.zero,
            context: <String, Object?>{
              'phase': 'synthesis_exhausted',
              'article_id': articleId,
              'chunk_index': index,
              'strategy': _ttsService.lastSynthesisDebugInfo.strategy,
            },
          );
          return null;
        }

        await Future.delayed(delay);
        delay *= 2; // Exponential back-off
      }
    }

    return null;
  }

  Future<String> _getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  Future<void> _restoreAudioPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final speed =
          (prefs.getDouble(TtsPreferenceKeys.playbackSpeed) ??
                  prefs.getDouble(TtsPreferenceKeys.legacySpeed) ??
                  _playbackSpeed)
              .clamp(0.5, 2.0)
              .toDouble();
      _playbackSpeed = speed;
      await _audioHandler?.setSpeed(speed);

      final synthesisRate =
          (prefs.getDouble(TtsPreferenceKeys.synthesisRate) ??
                  _baseSynthesisRate)
              .clamp(0.3, 0.6)
              .toDouble();
      _baseSynthesisRate = synthesisRate;
      await _ttsService.setRate(synthesisRate);

      final pitch =
          (prefs.getDouble(TtsPreferenceKeys.pitch) ?? _baseSynthesisPitch)
              .clamp(0.9, 1.08)
              .toDouble();
      _baseSynthesisPitch = pitch;
      await _ttsService.setPitch(pitch);

      final volume = (prefs.getDouble(TtsPreferenceKeys.volume) ?? 1.0)
          .clamp(0.0, 1.0)
          .toDouble();
      final handler = _audioHandler;
      if (handler is TtsPlayerHandler) {
        await handler.setVolume(volume);
      }

      final voiceName = prefs.getString(TtsPreferenceKeys.voiceName);
      final voiceLocale = prefs.getString(TtsPreferenceKeys.voiceLocale);
      final availableVoices = await getAvailableVoices();
      if (voiceName != null &&
          voiceName.isNotEmpty &&
          voiceLocale != null &&
          voiceLocale.isNotEmpty) {
        final savedVoice = availableVoices.firstWhere(
          (voice) =>
              voice['name'] == voiceName && voice['locale'] == voiceLocale,
          orElse: () => const <String, String>{},
        );
        if (savedVoice.isNotEmpty) {
          await _ttsService.setVoice(voiceName, voiceLocale);
          await _safeSetLanguage(voiceLocale);
        } else {
          final fallbackVoice = TtsVoiceHeuristics.pickBestVoiceMap(
            availableVoices,
            preferredLanguageCode: _currentArticleLanguage,
          );
          if (fallbackVoice != null) {
            await setVoice(fallbackVoice['name']!, fallbackVoice['locale']!);
          }
        }
      } else {
        final fallbackVoice = TtsVoiceHeuristics.pickBestVoiceMap(
          availableVoices,
          preferredLanguageCode: _currentArticleLanguage,
        );
        if (fallbackVoice != null) {
          await setVoice(fallbackVoice['name']!, fallbackVoice['locale']!);
        }
      }

      final presetName = prefs.getString(TtsPreferenceKeys.preset);
      if (presetName != null) {
        _currentPreset = TtsPreset.values.firstWhere(
          (e) => e.name == presetName,
          orElse: () => TtsPreset.natural,
        );
      }
      _activePresetForSession = _currentPreset;
    } catch (e) {
      if (e is MissingPluginException) return;
      debugPrint('[TtsManager] Failed to restore audio preferences: $e');
    }
  }

  Future<void> _safeSetLanguage(String language) async {
    final candidate = _normalizedLanguageCode(language);
    if (candidate.isEmpty) return;
    try {
      await _ttsService.setLanguage(candidate);
    } catch (e) {
      debugPrint('[TtsManager] setLanguage failed for "$candidate": $e');
      await _analytics.trackSynthesisError(
        'setLanguage failed for $candidate: $e',
        Duration.zero,
      );
    }
  }

  String _normalizedLanguageCode(String raw) {
    return TtsVoiceHeuristics.normalizeLanguageCode(raw);
  }

  TtsPreset _resolvePresetForSession(String? preferredPresetName) {
    if (preferredPresetName == null || preferredPresetName.isEmpty) {
      return _currentPreset;
    }
    return TtsPreset.values.firstWhere(
      (preset) => preset.name == preferredPresetName,
      orElse: () => _currentPreset,
    );
  }

  String _buildActiveSynthesisProfileKey({
    required String language,
    required String category,
  }) {
    return SpeechDeliveryIntelligence.buildSynthesisProfileKey(
      language: language,
      category: category,
      presetName: _activePresetForSession.name,
      baseRate: _baseSynthesisRate,
      basePitch: _baseSynthesisPitch,
      adaptiveRateBias: _activeAdaptiveProfile.rateBias,
      adaptivePitchBias: _activeAdaptiveProfile.pitchBias,
    );
  }

  void _retagChunksForActiveSpeechProfile() {
    if (_currentChunks.isEmpty) return;
    _currentChunks = _currentChunks
        .map(
          (chunk) =>
              chunk.copyWith(synthesisProfileKey: _activeSynthesisProfileKey),
        )
        .toList(growable: false);
  }

  Future<void> _ensureHumanLikeVoiceForLanguage(String language) async {
    try {
      final normalizedLanguage = _normalizedLanguageCode(language);
      if (normalizedLanguage.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(TtsPreferenceKeys.voiceName);
      final savedLocale = prefs.getString(TtsPreferenceKeys.voiceLocale);
      final availableVoices = TtsVoiceHeuristics.sortVoiceMaps(
        await getAvailableVoices(),
        preferredLanguageCode: normalizedLanguage,
      );
      if (availableVoices.isEmpty) return;

      final hasMatchingSavedVoice =
          savedName != null &&
          savedName.isNotEmpty &&
          savedLocale != null &&
          savedLocale.isNotEmpty &&
          TtsVoiceHeuristics.matchesLanguage(savedLocale, normalizedLanguage) &&
          availableVoices.any(
            (voice) =>
                voice['name'] == savedName && voice['locale'] == savedLocale,
          );

      if (hasMatchingSavedVoice) return;

      final preferredVoice = availableVoices.first;
      await setVoice(preferredVoice['name']!, preferredVoice['locale']!);
    } catch (e) {
      if (e is MissingPluginException) return;
      debugPrint('[TtsManager] Failed to ensure human-like voice: $e');
      await _analytics.trackSynthesisError(
        'Voice selection failed: $e',
        Duration.zero,
      );
    }
  }

  Future<void> _persistDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (e) {
      if (e is MissingPluginException) return;
      debugPrint('[TtsManager] Failed to persist double "$key": $e');
    }
  }

  Future<void> _persistString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      if (e is MissingPluginException) return;
      debugPrint('[TtsManager] Failed to persist string "$key": $e');
    }
  }

  void _setCurrentSession(TtsSession? session) {
    _currentSession = session;
    if (!_sessionController.isClosed) {
      _sessionController.add(session);
    }
  }

  void _updateDiagnostics({
    TtsRuntimePhase? phase,
    Object? message = _diagnosticsUnset,
    Object? lastError = _diagnosticsUnset,
    Object? articleId = _diagnosticsUnset,
    Object? articleTitle = _diagnosticsUnset,
    Object? chunkIndex = _diagnosticsUnset,
    Object? totalChunks = _diagnosticsUnset,
    Object? requestedOutputPath = _diagnosticsUnset,
    Object? resolvedOutputPath = _diagnosticsUnset,
    Object? synthesisStrategy = _diagnosticsUnset,
    Object? usedCachedAudio = _diagnosticsUnset,
  }) {
    final resolvedArticleId = identical(articleId, _diagnosticsUnset)
        ? (_currentDiagnostics.articleId ?? _currentSession?.articleId)
        : articleId as String?;
    final resolvedArticleTitle = identical(articleTitle, _diagnosticsUnset)
        ? (_currentDiagnostics.articleTitle ?? _currentSession?.articleTitle)
        : articleTitle as String?;
    final resolvedChunkIndex = identical(chunkIndex, _diagnosticsUnset)
        ? (_currentDiagnostics.chunkIndex ?? _currentSession?.currentChunkIndex)
        : chunkIndex as int?;
    final resolvedTotalChunks = identical(totalChunks, _diagnosticsUnset)
        ? (_currentDiagnostics.totalChunks ??
              (_currentChunks.isNotEmpty ? _currentChunks.length : null))
        : totalChunks as int?;

    _currentDiagnostics = _currentDiagnostics.copyWith(
      phase: phase,
      message: message,
      lastError: lastError,
      articleId: resolvedArticleId,
      articleTitle: resolvedArticleTitle,
      chunkIndex: resolvedChunkIndex,
      totalChunks: resolvedTotalChunks,
      requestedOutputPath: requestedOutputPath,
      resolvedOutputPath: resolvedOutputPath,
      synthesisStrategy: synthesisStrategy,
      usedCachedAudio: usedCachedAudio,
      updatedAt: DateTime.now(),
    );
    if (!_diagnosticsController.isClosed) {
      _diagnosticsController.add(_currentDiagnostics);
    }
  }

  String _chunkLabel(int index) {
    if (_currentChunks.isEmpty) return 'part ${index + 1}';
    return 'part ${index + 1} of ${_currentChunks.length}';
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  void dispose() {
    _sleepTimer.dispose();
    clearFeedNavigation();
    _chunkIndexController.close();
    _chunkController.close();
    _sessionController.close();
    _diagnosticsController.close();
    _preloader
      ..clear()
      ..dispose();
    _synthesisQueue.clear();

    final handler = _audioHandler;
    if (handler is TtsPlayerHandler) handler.dispose();
  }
}
