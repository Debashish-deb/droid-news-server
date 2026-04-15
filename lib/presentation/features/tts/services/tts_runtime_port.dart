import 'package:audio_service/audio_service.dart';

import '../../../../core/tts/domain/entities/tts_chunk.dart';
import '../domain/models/speech_chunk.dart';
import '../domain/models/tts_session.dart';
import '../domain/models/tts_runtime_diagnostics.dart';
import 'tts_prosody_builder.dart';

abstract class TtsRuntimePort {
  Stream<int> get currentChunkIndex;
  Stream<SpeechChunk?> get currentChunk;
  Stream<TtsSession?> get sessionStream;
  Stream<PlaybackState> get playbackState;
  Stream<MediaItem?> get mediaItem;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<Duration?> get sleepTimerRemaining;
  Stream<TtsRuntimeDiagnostics> get diagnosticsStream;

  TtsSession? get currentSession;
  TtsRuntimeDiagnostics get currentDiagnostics;
  int get totalChunks;
  int get currentChunkNumber;
  String get currentArticleTitle;
  Duration get estimatedTimeRemaining;
  double get currentSpeed;
  double get currentPitch;
  double get currentSynthesisRate;
  TtsPreset get currentPreset;
  String get currentLanguage;
  bool get canGoPreviousFeedArticle;
  bool get canGoNextFeedArticle;

  Future<void> playArticle(
    String articleId,
    String title,
    String content, {
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
  });

  Future<void> playReaderChunks(
    List<TtsChunk> chunks, {
    required String title,
    String language = 'en',
    String category = 'general',
    String? author,
    String? imageSource,
    String? introAnnouncement,
  });

  Future<void> pause();
  Future<void> resume();
  Future<void> retry();
  Future<void> stop();
  Future<void> seekToChunk(int index);
  Future<void> seekRelative(Duration offset);
  Future<void> next();
  Future<void> previous();
  Future<void> setSpeed(double speed);
  Future<void> setPitch(double pitch);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setPreset(TtsPreset preset);
  Future<void> setVoice(String name, String locale);
  Future<List<Map<String, String>>> getAvailableVoices();
  void setSleepTimer(Duration duration);
}
