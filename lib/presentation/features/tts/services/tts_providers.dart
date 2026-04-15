import '../../../providers/feature_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show StreamProvider;
import 'package:audio_service/audio_service.dart';
import '../domain/models/tts_runtime_diagnostics.dart';

final ttsPlaybackStateProvider = StreamProvider<PlaybackState>((ref) {
  final coordinator = ref.watch(appTtsCoordinatorProvider);
  return coordinator.playbackState;
});

final ttsMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final coordinator = ref.watch(appTtsCoordinatorProvider);
  return coordinator.mediaItem;
});

final ttsDiagnosticsProvider = StreamProvider<TtsRuntimeDiagnostics>((ref) {
  final coordinator = ref.watch(appTtsCoordinatorProvider);
  return coordinator.diagnosticsStream;
});
