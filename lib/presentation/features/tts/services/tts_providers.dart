import '../../../providers/feature_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show StreamProvider;
import 'package:audio_service/audio_service.dart';

final ttsPlaybackStateProvider = StreamProvider<PlaybackState>((ref) {
  final manager = ref.watch(ttsManagerProvider);
  return manager.playbackState;
});

final ttsMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final manager = ref.watch(ttsManagerProvider);
  return manager.mediaItem;
});
