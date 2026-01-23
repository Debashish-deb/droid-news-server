import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'tts_manager.dart';

final ttsManagerProvider = Provider<TtsManager>((ref) {
  return TtsManager.instance;
});

final ttsPlaybackStateProvider = StreamProvider<PlaybackState>((ref) {
  return TtsManager.instance.playbackState;
});

final ttsMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return TtsManager.instance.mediaItem;
});
