import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class TtsPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  TtsPlayerHandler() {
    // Broadcast playback state changes
    _player.playbackEventStream.listen(_broadcastState);
    
    // Broadcast duration changes (optional for TTS chunks, but good for UX)
    _player.durationStream.listen((duration) {
       // update metadata duration if needed
    });
    
    // Auto-advance is handled by TtsManager usually, or ConcatenatingAudioSource?
    // "Industrial" suggests gapless playback.
    // Chunk playback events need to be observed.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Signal completion
        stop(); 
      }
    });
  }

  /// Broadcasts the current state to all listeners.
  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
  
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    print("TTS_DEBUG: TtsPlayerHandler.playFromUri called with URI: ${uri.path}");
    
    try {
      // Reconstruct valid MediaItem from extras if possible
      final item = MediaItem(
        id: uri.path,
        album: extras?['album'] as String? ?? "Reading",
        title: extras?['title'] as String? ?? "Article",
        artist: extras?['artist'] as String? ?? "News Reader",
        duration: null,
        extras: extras,
      );
      
      print("TTS_DEBUG: Setting MediaItem: ${item.title}");
      mediaItem.add(item);
      
      print("TTS_DEBUG: Setting audio file path: ${uri.path}");
      await _player.setFilePath(uri.path);
      
      print("TTS_DEBUG: Calling player.play()");
      await _player.play();
      
      print("TTS_DEBUG: Playback started successfully");
    } catch (e, stack) {
      print("TTS_DEBUG: ERROR in playFromUri: $e");
      print("TTS_DEBUG: Stack trace: $stack");
      rethrow;
    }
  }

  /// Custom action to play a specific file
  Future<void> playFile(String path, MediaItem metadata) async {
    mediaItem.add(metadata);
    await _player.setFilePath(path);
    await _player.play();
  }
}
