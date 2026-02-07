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
    this.progress = 0.0,
    this.error,
  });

  factory TtsState.idle() => const TtsState(status: TtsStatus.idle);
  final TtsStatus status;
  final int currentChunk;
  final double progress;
  final String? error;

  TtsState copyWith({
    TtsStatus? status,
    int? currentChunk,
    double? progress,
    String? error,
  }) {
    return TtsState(
      status: status ?? this.status,
      currentChunk: currentChunk ?? this.currentChunk,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}
