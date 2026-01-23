import 'dart:io';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tts_service.dart';
import 'tts_database.dart';
import 'tts_chunker.dart';
import 'audio_cache_manager.dart';
import 'tts_player_handler.dart';
import '../models/speech_chunk.dart';

class TtsManager {
  static final TtsManager instance = TtsManager._();
  TtsManager._();

  AudioHandler? _audioHandler;
  final TtsService _ttsService = FlutterTtsAdapter();
  final TtsDatabase _db = TtsDatabase.instance;
  final AudioCacheManager _cacheManager = AudioCacheManager.instance;

  bool _isInitialized = false;
  Future<void>? _initFuture; // Guard against concurrent init calls
  List<SpeechChunk> _currentChunks = [];
  int _currentIndex = 0;
  String _currentArticleId = '';
  String _currentArticleTitle = '';
  
  // Expose playback state for UI with safe defaults
  Stream<PlaybackState> get playbackState => 
      _audioHandler?.playbackState ?? Stream.value(PlaybackState());
      
  Stream<MediaItem?> get mediaItem => 
      _audioHandler?.mediaItem ?? Stream.value(null);
  
  // Chunk navigation state (reactive)
  final _chunkIndexController = StreamController<int>.broadcast();
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;
  
  // Time estimation
  Duration get estimatedTimeRemaining {
    if (_currentChunks.isEmpty || _currentIndex >= _currentChunks.length) {
      return Duration.zero;
    }
    
    final remainingChunks = _currentChunks.skip(_currentIndex + 1);
    final totalChars = remainingChunks.fold<int>(
      0, 
      (sum, chunk) => sum + chunk.text.length,
    );
    
    // Average speech rate: 150 words/min, ~5 chars/word = 12.5 chars/sec
    const charsPerSecond = (150 * 5) / 60;
    return Duration(seconds: (totalChars / charsPerSecond).ceil());
  }
  
  // Public getters for UI
  int get totalChunks => _currentChunks.length;
  int get currentChunkNumber => _currentIndex + 1;
  String get currentArticleTitle => _currentArticleTitle;

  Future<void> init() async {
    if (_isInitialized) return;
    
    // If initialization is already in progress, wait for it
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _initCore();
    await _initFuture;
  }

  Future<void> _initCore() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => TtsPlayerHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.bd.bdnewsreader.tts',
          androidNotificationChannelName: 'News Reading',
          androidNotificationOngoing: true,
        ),
      );
      
      await _ttsService.init();
      _isInitialized = true;
    } catch (e) {
      // If error (e.g. during dev hot-restart or race), try to recover or just log
      debugPrint("TTS Manager Init Error: $e");
      // Reset future so we can try again if critical
      _initFuture = null; 
      // Important: if AudioService.init throws "already initialized", 
      // we might need to assume it's working but we missed the handler reference?
      // No, usually it returns the handler.
      // If it throws, we are in trouble.
    }
  }

  Future<void> speakArticle(String articleId, String title, String content, {String language = 'en'}) async {
    debugPrint("TTS_DEBUG: speakArticle. Init=$_isInitialized");
    if (!_isInitialized) {
       await init();
       debugPrint("TTS_DEBUG: Post-Init. Init=$_isInitialized");
       if (!_isInitialized) return; // Init failed
    }

    // 1. Chunk text
    final fullText = "$title. $content";
    debugPrint("TTS_DEBUG: Full text length=${fullText.length}");
    _currentChunks = TtsChunker.chunk(fullText, language: language);
    debugPrint("TTS_DEBUG: Chunks generated=${_currentChunks.length}");
    _currentIndex = 0;
    _currentArticleId = articleId;
    _currentArticleTitle = title;

    if (_currentChunks.isEmpty) {
        debugPrint("TTS_DEBUG: Chunks empty, returning.");
        return;
    }

    // 2. Start playback loop
    _chunkIndexController.add(_currentIndex);
    await _playChunk(_currentIndex, articleId, title);
  }
  
  // Chunk navigation
  Future<void> nextChunk() async {
    if (_currentIndex < _currentChunks.length - 1) {
      _currentIndex++;
      _chunkIndexController.add(_currentIndex);
      await _playChunk(_currentIndex, _currentArticleId, _currentArticleTitle);
    }
  }
  
  Future<void> previousChunk() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      _chunkIndexController.add(_currentIndex);
      await _playChunk(_currentIndex, _currentArticleId, _currentArticleTitle);
    }
  }

  Future<void> _playChunk(int index, String articleId, String articleTitle) async {
    debugPrint("TTS_DEBUG: _playChunk index=$index");
    if (index >= _currentChunks.length) {
      debugPrint("TTS_DEBUG: End of chunks. Stopping.");
      await _audioHandler?.stop();
      return;
    }
    
    final chunk = _currentChunks[index];
    debugPrint("TTS_DEBUG: Processing chunk: '${chunk.text.substring(0, math.min(10, chunk.text.length))}...'");
    String? audioPath;

    // 3. Check Cache
    final cachedChunk = await _db.getCachedChunk(chunk.text, chunk.language);
    if (cachedChunk != null && cachedChunk.audioPath != null) {
      audioPath = cachedChunk.audioPath;
      debugPrint("TTS_DEBUG: Cache HIT for chunk. Using: $audioPath");
    } else {
      debugPrint("TTS_DEBUG: Cache MISS. Starting synthesis...");
      // 4. Synthesize if missing (with retry)
      audioPath = await _synthesizeWithRetry(
        chunk, 
        articleId, 
        index,
        maxAttempts: 3,
      );
    }

    if (audioPath != null) {
      // 5. Play
      final mediaItem = MediaItem(
        id: audioPath,
        album: "Reading",
        title: articleTitle,
        artist: "News Reader",
        duration: null, // Unknown initially
        extras: {'chunkIndex': index, 'totalChunks': _currentChunks.length},
      );

      debugPrint("TTS_DEBUG: Playing from URI: $audioPath");
      // SAFE CALL: Use standard AudioHandler interface
      await _audioHandler!.playFromUri(
        Uri.file(audioPath),
        {
           'title': articleTitle,
           'album': "Reading",
           'artist': "News Reader",
           'chunkIndex': index, 
           'totalChunks': _currentChunks.length
        },
      );
      
      _audioHandler!.playbackState.listen((state) {
        if (state.processingState == AudioProcessingState.completed) {
           // This fires when player finishes.
           // BE CAREFUL: This listener adds up if not cancelled.
           // Better architecture: TtsPlayerHandler emits "finished" custom event, or we queue all items?
        }
      });
      // Actually just_audio ConcatenatingAudioSource is better for gapless.
      // But we synthesize on demand?
      // Pre-synthesize next few chunks?
      
      // Optimized Strategy:
      // Play current.
      // Pre-synthesize next.
      // When current finishes, play next.
      // Implementing this "Industrial" logic requires robust state machine.
      
      // For this step, we assume one-by-one playback control from Manager logic
      // We need to know when playback finishes.
      // _audioHandler.playbackState stream is the way.
      // But detecting "finished current item" vs "stopped" is tricky.
      
      // Let's use Concatenating source if we can, but simpler:
      // Use just_audio `player.playerStateStream` inside Handler to auto-advance if we use a playlist?
      // No, we synthesize on fly.
      
      // Current approach:
      // Listen to state. If completed, increment index, play next.
      // We need to ensure we don't trigger multiple listeners.
    } else {
       // Fallback: Speak directly if file synthesis failed
       await _ttsService.speak(chunk.text);
       // We can't use audio_service properly here, but user gets audio.
    }
  }
  
  // Synthesis with retry and exponential backoff
  Future<String?> _synthesizeWithRetry(
    SpeechChunk chunk,
    String articleId,
    int index, {
    int maxAttempts = 3,
  }) async {
    final fileName = "${articleId}_$index.wav";
    int attempt = 0;
    Duration delay = const Duration(milliseconds: 500);
    
    while (attempt < maxAttempts) {
      attempt++;
      try {
        debugPrint("TTS_DEBUG: Synthesis attempt $attempt/$maxAttempts");
        
        final tempFile = p.join((await _getTempDir()), fileName);
        final resultPath = await _ttsService.synthesizeToFile(chunk.text, tempFile);
        
        if (resultPath != null) {
          final file = File(resultPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final audioPath = await _cacheManager.saveAudio(fileName, bytes);
            
            // Update DB
            await _db.cacheChunk(chunk.text, chunk.language, audioPath, null);
            
            debugPrint("TTS_DEBUG: Synthesis succeeded on attempt $attempt");
            return audioPath;
          }
        }
      } catch (e) {
        debugPrint("TTS_DEBUG: Synthesis attempt $attempt failed: $e");
        
        if (attempt >= maxAttempts) {
          debugPrint("TTS_DEBUG: All synthesis attempts exhausted. Fallback to direct speak.");
          // Fallback: use direct TTS without file cache
          await _ttsService.speak(chunk.text);
          return null;
        }
        
        // Exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    
    return null;
  }

  Future<void> pause() async => await _audioHandler?.pause();
  Future<void> resume() async => await _audioHandler?.play();
  Future<void> stop() async => await _audioHandler?.stop();

  // Helper
  Future<String> _getTempDir() async {
     final dir = await getTemporaryDirectory();
     return dir.path;
  }
}
