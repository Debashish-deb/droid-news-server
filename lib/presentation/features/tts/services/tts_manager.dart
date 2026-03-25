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

// ── Top-level isolate helper ──────────────────────────────────────────────────
//
// TextCleaner.clean() runs regex passes over the full article body.
// On a 5,000-word article this can block the main isolate for 50-150ms,
// dropping frames.  compute() offloads this to a worker isolate so the UI
// stays at 60fps.

Future<String> _cleanTextInIsolate(String raw) async =>
    compute(_cleanWorker, raw);

String _cleanWorker(String raw) => TextCleaner.clean(raw);

const _kTtsSpeed = 'tts_speed';
const _kTtsPitch = 'tts_pitch';
const _kTtsVolume = 'tts_volume';
const _kTtsVoiceName = 'tts_voice_name';
const _kTtsVoiceLocale = 'tts_voice_locale';
const _kTtsPreset = 'tts_preset';

// ─────────────────────────────────────────────────────────────────────────────

class TtsManager {
  TtsManager({
    required TtsRepository repository,
    required TtsAnalytics analytics,
    required SynthesisCircuitBreaker circuitBreaker,
    required TtsPerformanceMonitor performanceMonitor,
    required PipelineOrchestrator pipelineOrchestrator,
    required AudioCacheManager cacheManager,
  }) : _repository = repository,
       _analytics = analytics,
       _circuitBreaker = circuitBreaker,
       _performanceMonitor = performanceMonitor,
       _pipelineOrchestrator = pipelineOrchestrator,
       _cacheManager = cacheManager {
    _ttsService = FlutterTtsAdapter();
    _preloader = ChunkPreloader(synthesizeChunk: _synthesizeChunkForPreloader);
    _sleepTimer = TtsSleepTimer(onSleepTimerExpired: stop);
  }

  @visibleForTesting
  TtsManager.createTestInstance({
    required TtsRepository repository,
    required ChunkPreloader preloader,
    required AudioHandler audioHandler,
    required TtsService ttsService,
    required AudioCacheManager cacheManager,
    required PipelineOrchestrator pipelineOrchestrator,
    TtsAnalytics? analytics,
  }) : _repository = repository,
       _preloader = preloader,
       _audioHandler = audioHandler,
       _ttsService = ttsService,
       _cacheManager = cacheManager,
       _pipelineOrchestrator = pipelineOrchestrator,
       _analytics = analytics ?? TtsAnalytics(),
       _circuitBreaker = SynthesisCircuitBreaker(
         analytics: analytics ?? TtsAnalytics(),
       ),
       _performanceMonitor = TtsPerformanceMonitor(
         analytics: analytics ?? TtsAnalytics(),
       ) {
    _sleepTimer = TtsSleepTimer(onSleepTimerExpired: stop);
  }

  // ── Dependencies ───────────────────────────────────────────────────────────
  final TtsRepository _repository;
  final TtsAnalytics _analytics;
  final SynthesisCircuitBreaker _circuitBreaker;
  final TtsPerformanceMonitor _performanceMonitor;
  final PipelineOrchestrator _pipelineOrchestrator;
  final AudioCacheManager _cacheManager;
  late final ChunkPreloader _preloader;

  AudioHandler? _audioHandler;
  late TtsService _ttsService;

  // ── Session state ──────────────────────────────────────────────────────────
  TtsSession? _currentSession;
  List<SpeechChunk> _currentChunks = [];
  bool _isInitialized = false;
  Future<void>? _initFuture;
  final TtsSynthesisQueue _synthesisQueue = TtsSynthesisQueue();

  // Synthesis baseline tuned for natural voice; playback speed is still
  // controlled by the audio player.
  double _baseSynthesisRate = 0.44;
  double _baseSynthesisPitch = 0.94;
  double _playbackSpeed = 1.0;
  TtsPreset _currentPreset = TtsPreset.natural;

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

  /// Remaining sleep time; null when no timer is active.
  Stream<Duration?> get sleepTimerRemaining => _sleepTimer.sleepTimerRemaining;

  double get currentSpeed => _playbackSpeed;
  TtsPreset get currentPreset => _currentPreset;
  double get currentPitch => _baseSynthesisPitch;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _initFuture = _initCore();
    await _initFuture;
  }

  Future<void> _initCore() async {
    try {
      // Use the factory that wires onChunkCompleted at construction time,
      // eliminating the nullable-callback race from the original code.
      _audioHandler ??= await AudioService.init(
        builder: () => TtsPlayerHandler(onChunkCompleted: _onChunkCompleted),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.bd.bdnewsreader.tts',
          androidNotificationChannelName: 'News Reading',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
        ),
      );

      await _ttsService.init();
      await _ttsService.setRate(_baseSynthesisRate);
      await _ttsService.setPitch(_baseSynthesisPitch);
      await _restoreAudioPreferences();

      final lastSession = await _repository.getLastSession();
      if (lastSession != null && lastSession.isResumable) {
        _currentSession = lastSession;
        debugPrint(
          '[TtsManager] Restored session: ${lastSession.articleTitle}',
        );
      }

      _isInitialized = true;
      debugPrint('[TtsManager] Initialized successfully.');
    } catch (e, st) {
      debugPrint('[TtsManager] Init error: $e\n$st');
      await _analytics.trackSynthesisError('Init failed: $e', Duration.zero);
      _isInitialized = false;
      _initFuture = null;
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
      _currentSession = _currentSession!.copyWith(
        state: TtsSessionState.completed,
      );
      await _repository.saveSession(_currentSession!);
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
    String? author,
    String? imageSource,
  }) async {
    if (!_isInitialized) {
      await init();
      if (!_isInitialized) return;
    }
    await _safeSetLanguage(language);

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
      return;
    }

    final result = await _pipelineOrchestrator.processArticle(
      articleId: articleId,
      title: title,
      content: cleanedContent,
      language: language,
      author: author,
      imageSource: imageSource,
      contentIsCleaned: true,
    );

    if (!result.success || result.session == null) {
      debugPrint('[TtsManager] Pipeline failed: ${result.error}');
      return;
    }

    _isStopping = false;
    _currentSession = result.session!.copyWith(state: TtsSessionState.playing);
    _currentChunks = result.chunks!;

    await _repository.saveSession(_currentSession!);
    debugPrint(
      '[TtsManager] Session created. Chunks: ${_currentChunks.length}',
    );

    if (_currentChunks.isEmpty) return;

    _chunkIndexController.add(0);
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
    _currentSession = _currentSession!.copyWith(currentChunkIndex: index);
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
      _currentSession = _currentSession!.copyWith(
        state: TtsSessionState.paused,
      );
      unawaited(_repository.saveSession(_currentSession!));
    }
    await _audioHandler?.pause();
    // Stop direct TTS fallback if active
    await _ttsService.stop();
  }

  Future<void> resume() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(state: TtsSessionState.playing);
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
      final ps = handler.playbackState.value.processingState;
      final isPaused =
          ps == AudioProcessingState.ready &&
          !handler.playbackState.value.playing;
      final isIdle = ps == AudioProcessingState.idle;

      if (isPaused) {
        // Resume from mid-stream — no re-synthesis needed
        await handler.play();
        return;
      }

      if (isIdle) {
        // Source was lost (e.g. background kill); re-synthesize this chunk
        final idx = _currentSession!.currentChunkIndex;
        if (idx < _currentChunks.length) {
          await _playChunk(idx);
        }
        return;
      }
    }
  }

  Future<void> setSpeed(double speed) async {
    final target = speed.clamp(0.5, 2.0).toDouble();
    _playbackSpeed = target;
    await _audioHandler?.setSpeed(target);
    unawaited(_persistDouble(_kTtsSpeed, target));
  }

  Future<void> setPitch(double pitch) async {
    _baseSynthesisPitch = pitch.clamp(0.8, 1.2).toDouble();
    await _ttsService.setPitch(_baseSynthesisPitch);
    unawaited(_persistDouble(_kTtsPitch, _baseSynthesisPitch));
  }

  Future<void> setVolume(double volume) async {
    final handler = _audioHandler;
    if (handler is TtsPlayerHandler) {
      final target = volume.clamp(0.0, 1.0).toDouble();
      await handler.setVolume(target);
      unawaited(_persistDouble(_kTtsVolume, target));
    }
  }

  Future<void> setRate(double rate) async {
    _baseSynthesisRate = rate.clamp(0.3, 0.6).toDouble();
    await _ttsService.setRate(_baseSynthesisRate);
    unawaited(_persistDouble(_kTtsSpeed, _baseSynthesisRate)); 
  }

  Future<void> setPreset(TtsPreset preset) async {
    _currentPreset = preset;
    unawaited(_persistString(_kTtsPreset, preset.name));
  }

  Future<void> stop() async {
    // Raise the flag FIRST so any pending _onChunkCompleted calls are ignored
    _isStopping = true;
    _sleepTimer.cancelSleepTimer();

    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        state: TtsSessionState.stopped,
      );
      unawaited(_repository.saveSession(_currentSession!));
    }

    _chunkController.add(null);
    _chunkIndexController.add(-1); // Hides the mini player

    await _audioHandler?.stop();
    await _ttsService.stop();

    _preloader.clear();
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
    await _ttsService.setVoice(name, locale);
    await _safeSetLanguage(locale);
    unawaited(_persistString(_kTtsVoiceName, name));
    unawaited(_persistString(_kTtsVoiceLocale, locale));
  }

  // ── Internal playback ──────────────────────────────────────────────────────

  Future<void> _playChunk(int index) async {
    if (index >= _currentChunks.length || _isStopping) return;

    final chunk = _currentChunks[index];
    _chunkController.add(chunk);

    String? audioPath;

    // Cache lookup
    final cachedChunk = await _repository.getCachedChunk(chunk);
    if (cachedChunk?.audioPath != null) {
      audioPath = cachedChunk!.audioPath;
      await _analytics.trackCacheHit(true);
    } else {
      await _analytics.trackCacheHit(false);
      audioPath = await _synthesizeChunk(chunk);
    }

    if (audioPath == null) {
      debugPrint('[TtsManager] Synthesis null for chunk $index; stopping.');
      if (_currentSession?.state == TtsSessionState.playing) stop();
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
      extras: {
        'chunkIndex': index,
        'totalChunks': _currentChunks.length,
        'articleId': _currentSession?.articleId,
        'title': _currentSession?.articleTitle ?? 'Article',
        'artist': 'News Reader',
      },
    );

    await _audioHandler!.playFromUri(Uri.file(audioPath), mediaItem.extras);
    _preloader.clearOldPreloads(index);

    // Kick off preloading for next chunks (fire-and-forget)
    unawaited(
      _preloader.preloadAhead(allChunks: _currentChunks, currentIndex: index),
    );
  }

  Future<String?> _synthesizeChunkForPreloader(SpeechChunk chunk) async {
    final cached = await _repository.getCachedChunk(chunk);
    if (cached?.audioPath != null) return cached!.audioPath;
    return _synthesizeChunk(chunk);
  }

  Future<String?> _synthesizeChunk(SpeechChunk chunk) async {
    return _synthesisQueue.runLocked(() async {
      try {
        final articleId = _currentSession?.articleId ?? 'unknown';
        return await _synthesizeWithRetry(chunk, articleId, chunk.id);
      } catch (e) {
        debugPrint('[TtsManager] Error synthesizing chunk: $e');
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
    final prosody = TtsProsodyBuilder.buildChunkProsody(
      chunk: chunk,
      baseSynthesisRate: _baseSynthesisRate,
      baseSynthesisPitch: _baseSynthesisPitch,
      preset: _currentPreset,
    );
    final safeId = articleId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final fileName = '${safeId}_$index.wav';

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
        );

        if (attempt >= maxAttempts) {
          debugPrint(
            '[TtsManager] All attempts exhausted; direct speak fallback.',
          );
          await _ttsService.speak(prosody.text);
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

      final speed = (prefs.getDouble(_kTtsSpeed) ?? _playbackSpeed)
          .clamp(0.5, 2.0)
          .toDouble();
      _playbackSpeed = speed;
      await _audioHandler?.setSpeed(speed);

      final pitch = (prefs.getDouble(_kTtsPitch) ?? _baseSynthesisPitch)
          .clamp(0.8, 1.2)
          .toDouble();
      _baseSynthesisPitch = pitch;
      await _ttsService.setPitch(pitch);

      final volume = (prefs.getDouble(_kTtsVolume) ?? 1.0)
          .clamp(0.0, 1.0)
          .toDouble();
      final handler = _audioHandler;
      if (handler is TtsPlayerHandler) {
        await handler.setVolume(volume);
      }

      final voiceName = prefs.getString(_kTtsVoiceName);
      final voiceLocale = prefs.getString(_kTtsVoiceLocale);
      if (voiceName != null &&
          voiceName.isNotEmpty &&
          voiceLocale != null &&
          voiceLocale.isNotEmpty) {
        await _ttsService.setVoice(voiceName, voiceLocale);
        await _safeSetLanguage(voiceLocale);
      }

      final presetName = prefs.getString(_kTtsPreset);
      if (presetName != null) {
        _currentPreset = TtsPreset.values.firstWhere(
          (e) => e.name == presetName,
          orElse: () => TtsPreset.natural,
        );
      }
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
    }
  }

  String _normalizedLanguageCode(String raw) {
    final code = raw.trim().replaceAll('_', '-');
    if (code.isEmpty) return '';
    switch (code.toLowerCase()) {
      case 'en':
        return 'en-US';
      case 'bn':
        return 'bn-BD';
      case 'hi':
        return 'hi-IN';
      default:
        return code;
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

  // ── Dispose ────────────────────────────────────────────────────────────────

  void dispose() {
    _sleepTimer.dispose();
    clearFeedNavigation();
    _chunkIndexController.close();
    _chunkController.close();
    _preloader
      ..clear()
      ..dispose();
    _synthesisQueue.clear();

    final handler = _audioHandler;
    if (handler is TtsPlayerHandler) handler.dispose();
  }
}
