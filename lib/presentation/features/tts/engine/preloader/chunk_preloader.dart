import 'dart:async';
import 'package:flutter/widgets.dart';

import '../../domain/models/speech_chunk.dart';

// Intelligent chunk preloader for gapless playback
// 
// Preloads upcoming chunks while current chunk is playing
// to ensure seamless transitions without gaps or stuttering.
// 
// [MEMORY AWARE]: Clears buffers on system memory warnings.
class ChunkPreloader with WidgetsBindingObserver {
  
  ChunkPreloader({
    required this.synthesizeChunk, this.bufferSize = 2,
  }) {
   
    WidgetsBinding.instance.addObserver(this);
  }
  final int bufferSize;
  final Future<String?> Function(SpeechChunk chunk) synthesizeChunk;
  
  final _preloadQueue = <SpeechChunk>[];
  final _preloadedPaths = <int, String>{};
  bool _isPreloading = false;
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didHaveMemoryPressure() {
    debugPrint('⚠️ [Preloader] CRITICAL MEMORY PRESSURE DETECTED. Clearing buffers.');
    clear(); 
  }
  
  Future<void> preloadAhead({
    required List<SpeechChunk> allChunks,
    required int currentIndex,
  }) async {
    if (_isPreloading) {
      debugPrint('[Preloader] Already preloading, skipping');
      return;
    }
    
    _isPreloading = true;
    
    try {
      final chunksToPreload = <SpeechChunk>[];
      
      for (int i = 1; i <= bufferSize; i++) {
        final nextIndex = currentIndex + i;
        if (nextIndex < allChunks.length) {
          final chunk = allChunks[nextIndex];
          
          if (!_preloadedPaths.containsKey(chunk.id) && 
              !chunk.hasCachedAudio) {
            chunksToPreload.add(chunk);
          }
        }
      }
      
      if (chunksToPreload.isEmpty) {
        debugPrint('[Preloader] Nothing to preload');
        _isPreloading = false;
        return;
      }
      
      debugPrint('[Preloader] Preloading ${chunksToPreload.length} chunk(s)');
      
      final futures = chunksToPreload.map((chunk) => _preloadChunk(chunk));
      await Future.wait(futures);
      
      debugPrint('[Preloader] ✅ Preloading complete');
    } catch (e) {
      debugPrint('[Preloader] ❌ Error: $e');
    } finally {
      _isPreloading = false;
    }
  }
  

  Future<void> _preloadChunk(SpeechChunk chunk) async {
    try {
      debugPrint('[Preloader] Synthesizing chunk ${chunk.id}');
      
      final audioPath = await synthesizeChunk(chunk);
      
      if (audioPath != null) {
        _preloadedPaths[chunk.id] = audioPath;
        debugPrint('[Preloader] ✅ Chunk ${chunk.id} ready: $audioPath');
      } else {
        debugPrint('[Preloader] ⚠️ Chunk ${chunk.id} synthesis failed');
      }
    } catch (e) {
      debugPrint('[Preloader] ❌ Chunk ${chunk.id} error: $e');
    }
  }
  

  String? getPreloadedPath(int chunkId) {
    return _preloadedPaths[chunkId];
  }
  

  void clearOldPreloads(int currentIndex) {
    final keysToRemove = <int>[];
    
    _preloadedPaths.forEach((chunkId, path) {
     
      if (chunkId < currentIndex - 1) {
        keysToRemove.add(chunkId);
      }
    });
    
    for (final key in keysToRemove) {
      _preloadedPaths.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      debugPrint('[Preloader] Cleared ${keysToRemove.length} old preloads');
    }
  }
  
  double getBufferHealth(int currentIndex, int totalChunks) {
    int bufferedAhead = 0;
    
    for (int i = 1; i <= bufferSize; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < totalChunks && _preloadedPaths.containsKey(nextIndex)) {
        bufferedAhead++;
      }
    }
    
    return bufferedAhead / bufferSize;
  }
  

  void clear() {
    _preloadedPaths.clear();
    _preloadQueue.clear();
    debugPrint('[Preloader] Cleared all preloads');
  }
  

  PreloaderStats getStats() {
    return PreloaderStats(
      preloadedCount: _preloadedPaths.length,
      isPreloading: _isPreloading,
      bufferSize: bufferSize,
    );
  }
}

// Preloader statistics
class PreloaderStats {
  
  const PreloaderStats({
    required this.preloadedCount,
    required this.isPreloading,
    required this.bufferSize,
  });
  final int preloadedCount;
  final bool isPreloading;
  final int bufferSize;
  
  @override
  String toString() {
    return 'PreloaderStats('
           'preloaded: $preloadedCount, '
           'active: $isPreloading, '
           'bufferSize: $bufferSize'
           ')';
  }
}
