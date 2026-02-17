import 'dart:io';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Core & Domain
import '../core/pipeline_orchestrator.dart';
import '../domain/models/speech_chunk.dart';
import '../domain/models/tts_session.dart';
import '../domain/repositories/tts_repository.dart';

// Engine
import '../engine/preloader/chunk_preloader.dart';

// Services
import 'tts_service.dart';
import 'audio_cache_manager.dart';
import 'tts_player_handler.dart';


import '../core/tts_analytics.dart';
import '../core/synthesis_circuit_breaker.dart';
import '../core/tts_performance_monitor.dart';


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
         _preloader = ChunkPreloader(
            synthesizeChunk: _synthesizeChunkForPreloader,
         );
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
       _circuitBreaker = SynthesisCircuitBreaker(analytics: analytics ?? TtsAnalytics()),
       _performanceMonitor = TtsPerformanceMonitor(analytics: analytics ?? TtsAnalytics());



  final TtsRepository _repository;
  final TtsAnalytics _analytics;
  final SynthesisCircuitBreaker _circuitBreaker;
  final TtsPerformanceMonitor _performanceMonitor;
  final PipelineOrchestrator _pipelineOrchestrator;
  final AudioCacheManager _cacheManager;
  late final ChunkPreloader _preloader;
  

  AudioHandler? _audioHandler;
  late TtsService _ttsService;
  

  TtsSession? _currentSession;
  List<SpeechChunk> _currentChunks = [];
  bool _isInitialized = false;
  Future<void>? _initFuture;

  final _chunkIndexController = StreamController<int>.broadcast();
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;
  
  final _chunkController = StreamController<SpeechChunk?>.broadcast();
  Stream<SpeechChunk?> get currentChunk => _chunkController.stream;

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
      _audioHandler ??= await AudioService.init(
          builder: () => TtsPlayerHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.bd.bdnewsreader.tts',
            androidNotificationChannelName: 'News Reading',
            androidNotificationOngoing: true,
          ),
        );
      
      if (_audioHandler is TtsPlayerHandler) {
        (_audioHandler as TtsPlayerHandler).onChunkCompleted = () {
           nextChunk();
        };
      }
      
      await _ttsService.init();
      
      final lastSession = await _repository.getLastSession();
      if (lastSession != null && lastSession.isResumable) {
        debugPrint("TTS_DEBUG: Restoring session: ${lastSession.articleTitle}");
        _currentSession = lastSession;
      }
      
      _isInitialized = true;
    } catch (e) {
      debugPrint("❌ TTS Init Error: $e");
      await _analytics.trackSynthesisError("Init failed: $e", Duration.zero);
      _initFuture = null;
    }
  }
  
  Stream<PlaybackState> get playbackState => 
      _audioHandler?.playbackState ?? Stream.value(PlaybackState());


  int get totalChunks => _currentChunks.length;
  int get currentChunkNumber => (_currentSession?.currentChunkIndex ?? 0) + 1;
  String get currentArticleTitle => _currentSession?.articleTitle ?? '';
  

  Duration get estimatedTimeRemaining {
      if (_currentChunks.isEmpty) return Duration.zero;
      
      final int currentIndex = _currentSession?.currentChunkIndex ?? 0;
      if (currentIndex >= _currentChunks.length) return Duration.zero;
      
      int charCount = 0;
      for (int i = currentIndex; i < _currentChunks.length; i++) {
        charCount += _currentChunks[i].text.length;
      }
      
      const charsPerSecond = 12.5;
      return Duration(seconds: (charCount / charsPerSecond).ceil());
  }


  Stream<MediaItem?> get mediaItem => 
      _audioHandler?.mediaItem ?? Stream.value(null);
      
 
  TtsSession? get currentSession => _currentSession;


  Future<List<Map<String, String>>> getAvailableVoices() => _ttsService.getVoices();
  
  Future<void> setVoice(String name, String locale) async {
    await _ttsService.setVoice(name, locale);
  }

  Future<void> setVolume(double volume) async {
    if (_audioHandler is TtsPlayerHandler) {
      await (_audioHandler as TtsPlayerHandler).setVolume(volume);
    }
  }

  Future<void> setPitch(double pitch) async {
    await _ttsService.setPitch(pitch);
  }



  Future<void> speakArticle(
    String articleId,
    String title,
    String content, {
    String language = 'en',
    String? author,
    String? imageSource,
  }) async {
    debugPrint("TTS_DEBUG: speakArticle. Init=$_isInitialized");
    if (!_isInitialized) {
       await init();
       if (!_isInitialized) return;
    }

    await _analytics.trackPlaybackStart(articleId);

    debugPrint("TTS_DEBUG: Processing article via pipeline...");
    final result = await _pipelineOrchestrator.processArticle(
      articleId: articleId,
      title: title,
      content: content,
      language: language,
      author: author,
      imageSource: imageSource,
    );
    
    if (!result.success || result.session == null) {
      debugPrint("❌ Pipeline failed: ${result.error}");
      
      return;
    }
    

    _currentSession = result.session!.copyWith(state: TtsSessionState.playing);
    _currentChunks = result.chunks!;
    

    await _repository.saveSession(_currentSession!);
    
    debugPrint("TTS_DEBUG: Session created. Chunks: ${_currentChunks.length}");
    
    if (_currentChunks.isEmpty) {
        debugPrint("TTS_DEBUG: Chunks empty, returning.");
        return;
    }

   
    _chunkIndexController.add(0);
    await _playChunk(0);
  }

  Future<void> speakChunks({
    required String articleId,
    required String title,
    required List<SpeechChunk> chunks,
  }) async {
    if (!_isInitialized) {
       await init();
       if (!_isInitialized) return;
    }

    _currentSession = TtsSession.create(
      articleId: articleId,
      articleTitle: title,
    ).copyWith(
      totalChunks: chunks.length,
      state: TtsSessionState.playing,
    );
    
    _currentChunks = chunks;
    
    await _repository.saveSession(_currentSession!);
    
    if (_currentChunks.isEmpty) return;

    _chunkIndexController.add(0);
    await _playChunk(0);
  }
  

  Future<void> nextChunk() async {
    if (_currentSession == null) return;
    
    if (_currentSession!.currentChunkIndex < _currentChunks.length - 1) {
      final nextIndex = _currentSession!.currentChunkIndex + 1;
      _updateSessionIndex(nextIndex);
      
      await Future.delayed(const Duration(milliseconds: 300));
      await _playChunk(nextIndex);
    } else {
      debugPrint("TTS_DEBUG: Article completed.");

      _currentSession = _currentSession!.copyWith(state: TtsSessionState.completed);
      await _repository.saveSession(_currentSession!);
      await _audioHandler?.stop();
    }
  }
  
  Future<void> previousChunk() async {
    if (_currentSession == null) return;
    
    if (_currentSession!.currentChunkIndex > 0) {
      final prevIndex = _currentSession!.currentChunkIndex - 1;
      _updateSessionIndex(prevIndex);
      await _playChunk(prevIndex);
    }
  }
  
  void _updateSessionIndex(int index) {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(currentChunkIndex: index);
      _repository.saveSession(_currentSession!);
      _chunkIndexController.add(index);
      
      if (index >= 0 && index < _currentChunks.length) {
        _chunkController.add(_currentChunks[index]);
      } else {
        _chunkController.add(null);
      }
    }
  }

  Future<void> _playChunk(int index) async {
    if (index >= _currentChunks.length) return;
    
    final chunk = _currentChunks[index];
    _chunkController.add(chunk);
    debugPrint("TTS_DEBUG: processing chunk $index: '${chunk.text.substring(0, math.min(10, chunk.text.length))}...'");
    String? audioPath;


    final cachedChunk = await _repository.getCachedChunk(chunk);
    if (cachedChunk != null && cachedChunk.audioPath != null) {
      audioPath = cachedChunk.audioPath;
      debugPrint("TTS_DEBUG: Cache HIT. Path: $audioPath");
      await _analytics.trackCacheHit(true);
    } else {
      debugPrint("TTS_DEBUG: Cache MISS. Synthesizing...");
      await _analytics.trackCacheHit(false);

      audioPath = await _synthesizeChunk(chunk);
    }

    if (audioPath != null) {
      if (_currentSession == null || 
          _currentSession!.state == TtsSessionState.stopped || 
          _currentSession!.currentChunkIndex != index) {
         debugPrint("TTS_DEBUG: Aborting playback for chunk $index (Cancelled/Skipped)");
         return;
      }
      

      final mediaItem = MediaItem(
        id: audioPath,
        album: "Reading",
        title: _currentSession?.articleTitle ?? "Article",
        artist: "News Reader",
        extras: {'chunkIndex': index, 'totalChunks': _currentChunks.length},
      );

      debugPrint("TTS_DEBUG: Playing URI: $audioPath");
      await _audioHandler!.playFromUri(
        Uri.file(audioPath),
        mediaItem.extras,
      );
      
      _preloader.preloadAhead(
        allChunks: _currentChunks,
        currentIndex: index,
      );
    } else {
      debugPrint("TTS_DEBUG: Failed to play chunk $index. Synthesis returned null.");
      if (_currentSession?.state == TtsSessionState.playing) {
         debugPrint("TTS_DEBUG: Stopping session due to playback failure.");
         stop();
      }
    }
  }
  
  Future<String?> _synthesizeChunkForPreloader(SpeechChunk chunk) async {
    final cached = await _repository.getCachedChunk(chunk);
    if (cached != null && cached.audioPath != null) {
      return cached.audioPath;
    }
    return await _synthesizeChunk(chunk);
  }
  
  Future<String?> _synthesizeChunk(SpeechChunk chunk) async {
    try {
      
      
      
      
      return await _synthesizeWithRetry(chunk, _currentSession?.articleId ?? 'unknown', chunk.id);
    } catch (e) {
      debugPrint("Error synthesizing chunk: $e");
      return null;
    }
  }
  

  Future<String?> _synthesizeWithRetry(
    SpeechChunk chunk,
    String articleId,
    int index, {
    int maxAttempts = 3,
  }) async {
    final safeId = articleId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final fileName = "${safeId}_$index.wav";
    
    int attempt = 0;
    Duration delay = const Duration(milliseconds: 500);
    
    while (attempt < maxAttempts) {
      if (_currentSession == null || 
          _currentSession!.articleId != articleId ||
          _currentSession!.state == TtsSessionState.stopped) {
        debugPrint("TTS_DEBUG: Synthesis aborted for $index (Session changed/stopped)");
        return null;
      }

      attempt++;
      try {
        debugPrint("TTS_DEBUG: Synthesis attempt $attempt/$maxAttempts");
        
        final tempFile = p.join((await _getTempDir()), fileName);
        final stopwatch = Stopwatch()..start();

        final resultPath = await _circuitBreaker.execute(() async {
           return await _ttsService.synthesizeToFile(chunk.text, tempFile);
        });
        
        stopwatch.stop();
        _performanceMonitor.recordLatency(stopwatch.elapsed);
        
        if (resultPath != null) {
          final file = File(resultPath);
          if (await file.exists()) {
             final int size = await file.length();
             debugPrint("TTS_DEBUG: File created. Size: $size bytes. Path: $resultPath");
             
            if (size > 0) {
                final bytes = await file.readAsBytes();
                final audioPath = await _cacheManager.saveAudio(fileName, bytes);
                
      
                await _repository.cacheChunk(chunk, audioPath);
                
                debugPrint("TTS_DEBUG: Synthesis succeeded on attempt $attempt");
                return audioPath;
             } else {
                debugPrint("TTS_DEBUG: Synthesis failed: File is 0 bytes.");
             }
          }
        }
      } catch (e) {
        debugPrint("TTS_DEBUG: Synthesis attempt $attempt failed: $e");
        await _analytics.trackSynthesisError("Attempt $attempt failed: $e", Duration.zero);
        
        if (attempt >= maxAttempts) {
          debugPrint("TTS_DEBUG: All synthesis attempts exhausted. Fallback to direct speak.");
          await _ttsService.speak(chunk.text);
          return null;
        }
        
       
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    
    return null;
  }

  Future<void> pause() async { 
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(state: TtsSessionState.paused);
      await _repository.saveSession(_currentSession!);
    }
    // Handle both AudioHandler (file playback) and direct TTS (fallback)
    await _audioHandler?.pause();
    await _ttsService.stop(); // flutter_tts doesn't have pause, only stop (resume restarts from diff position usually, but acceptable for detailed reading)
  }
  
  Future<void> resume() async {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(state: TtsSessionState.playing);
      await _repository.saveSession(_currentSession!);
      // If we were paused, we might need to replay the current chunk
      // Check if AudioHandler is playing. If not, maybe we need to restart the chunk.
      // Simply calling play() on AudioHandler works if it was file playback.
      // If it was fallback, we need to call speak() again.
      final index = _currentSession!.currentChunkIndex;
      if (index < _currentChunks.length) {
         // Optimization: Try to resume via AudioHandler, if fails/idle, re-trigger playChunk
         await _audioHandler?.play();
         // If playback state is still idle/stopped after small delay, re-synthesize/play
         await Future.delayed(const Duration(milliseconds: 100));
         // This is complex. Simplest valid resume is to re-play the chunk.
         await _playChunk(index); 
      }
    }
  }

  Future<void> setSpeed(double speed) async {
    await _audioHandler?.setSpeed(speed);
    await _ttsService.setSpeed(speed);
  }
  
  Future<void> stop() async {
    if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(state: TtsSessionState.stopped);
        await _repository.saveSession(_currentSession!);
    }
    _chunkController.add(null);
    _chunkIndexController.add(-1); // Critical: Triggers UI hide
    
    await _audioHandler?.stop();
    await _ttsService.stop();
    
    _preloader.clear();
  }
  
  void dispose() {
    _chunkIndexController.close();
    _chunkController.close();
    _preloader.clear();
  }


  Future<String> _getTempDir() async {
     final dir = await getTemporaryDirectory();
     return dir.path;
  }
}
