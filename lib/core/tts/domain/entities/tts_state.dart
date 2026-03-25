import 'tts_config.dart';

enum TtsStatus {
  idle,
  loading,
  playing,
  paused,
  buffering,
  completed,
  stopped,
  error,
}

class TtsState {
  const TtsState({
    required this.status,
    this.currentChunk = 0,
    this.totalChunks = 0,
    this.progressFraction = 0.0,
    this.language = 'en',
    this.config = const TtsConfig(),
    this.error,
  });

  factory TtsState.idle() => const TtsState(status: TtsStatus.idle);

  final TtsStatus status;
  final int currentChunk;
  final int totalChunks;
  final double progressFraction;
  final String language;
  final TtsConfig config;
  final String? error;

  TtsState copyWith({
    TtsStatus? status,
    int? currentChunk,
    int? totalChunks,
    double? progressFraction,
    String? language,
    TtsConfig? config,
    String? error,
  }) {
    return TtsState(
      status: status ?? this.status,
      currentChunk: currentChunk ?? this.currentChunk,
      totalChunks: totalChunks ?? this.totalChunks,
      progressFraction: progressFraction ?? this.progressFraction,
      language: language ?? this.language,
      config: config ?? this.config,
      error: error ?? this.error,
    );
  }
}
