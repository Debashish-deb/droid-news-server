import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../engine/player/playback_watchdog.dart';

class TtsPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {

  TtsPlayerHandler() {
    _watchdog = PlaybackWatchdog(
      player: _player,
      onStuck: () {
        print("TTS_DEBUG: Watchdog detected stuck state. Skipping chunk.");
       
        onChunkCompleted?.call();
      },
      onError: () {
        print("TTS_DEBUG: Watchdog reported error.");
        onChunkCompleted?.call();
      },
    );
    
    _player.playbackEventStream.listen(_broadcastState);
    
    _player.durationStream.listen((duration) {
    });
    
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print("TTS_DEBUG: Chunk completed, notifying TtsManager");
        _watchdog.stopMonitoring();
        onChunkCompleted?.call();
      }
    });
  }
  final AudioPlayer _player = AudioPlayer();
  late final PlaybackWatchdog _watchdog;
  

  void Function()? onChunkCompleted;

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
  Future<void> play() async {
    _watchdog.startMonitoring();
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _watchdog.stopMonitoring();
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _watchdog.stopMonitoring();
    await _player.stop();
    await super.stop();
  }
  
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    print("TTS_DEBUG: TtsPlayerHandler.playFromUri called with URI: ${uri.path}");
    
    try {
      final item = MediaItem(
        id: uri.path,
        album: extras?['album'] as String? ?? "Reading",
        title: extras?['title'] as String? ?? "Article",
        artist: extras?['artist'] as String? ?? "News Reader",
        extras: extras,
      );
      
      print("TTS_DEBUG: Setting MediaItem: ${item.title}");
      mediaItem.add(item);
      
      print("TTS_DEBUG: Setting audio file path: ${uri.path}");
      await _player.setFilePath(uri.path);
      
      print("TTS_DEBUG: Calling player.play()");
      _watchdog.startMonitoring(); 
      await _player.play();
      
      print("TTS_DEBUG: Playback started successfully");
    } catch (e, stack) {
      print("TTS_DEBUG: ERROR in playFromUri: $e");
      print("TTS_DEBUG: Stack trace: $stack");
      _watchdog.stopMonitoring(); 
      rethrow;
    }
  }

  /// Custom action to play a specific file
  Future<void> playFile(String path, MediaItem metadata) async {
    mediaItem.add(metadata);
    await _player.setFilePath(path);
    _watchdog.startMonitoring();
    await _player.play();
  }
  
  /// Helper to dispose internal player resources
  void dispose() {
    _watchdog.dispose();
    _player.dispose();
  }
}
