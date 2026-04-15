import 'package:flutter/foundation.dart';

import 'tts_config.dart';

// ─── Status enum ─────────────────────────────────────────────────────────────

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

// ─── State ────────────────────────────────────────────────────────────────────

/// Immutable snapshot of TTS playback state, consumed by the UI layer.
@immutable
class TtsState {
  const TtsState({
    required this.status,
    this.currentChunk = 0,
    this.totalChunks = 0,
    this.progressFraction = 0.0,
    this.language = 'en',
    this.config = const TtsConfig(),
    this.estimatedPosition = Duration.zero,
    this.error,
  });

  factory TtsState.idle() => const TtsState(status: TtsStatus.idle);

  // Sentinel for the optional [error] field in [copyWith].
  static const Object _unsetError = Object();

  // ─── Fields ────────────────────────────────────────────────────────────────

  final TtsStatus status;

  /// Zero-based index of the sentence currently being spoken.
  final int currentChunk;

  /// Total number of chunks in the active article.
  final int totalChunks;

  /// Playback progress in [0.0, 1.0].
  final double progressFraction;

  /// BCP-47 language code of the current article.
  final String language;

  /// Active engine configuration.
  final TtsConfig config;

  /// Estimated playback position within the article. Updated by the controller
  /// using chunk-duration heuristics; not sample-accurate.
  final Duration estimatedPosition;

  /// Non-null only when [status] is [TtsStatus.error].
  final String? error;

  // ─── Computed: status booleans ────────────────────────────────────────────

  /// Playback is in progress (not paused, not idle).
  bool get isPlaying => status == TtsStatus.playing;

  /// Audio is paused mid-article.
  bool get isPaused => status == TtsStatus.paused;

  /// Waiting for data — either initial load or mid-stream buffering.
  bool get isLoading =>
      status == TtsStatus.loading || status == TtsStatus.buffering;

  /// The article has a session in flight (playing, paused, or loading).
  bool get isActive =>
      status == TtsStatus.playing ||
      status == TtsStatus.paused ||
      status == TtsStatus.buffering ||
      status == TtsStatus.loading;

  /// No article is loaded and nothing is happening.
  bool get isIdle => status == TtsStatus.idle || status == TtsStatus.stopped;

  /// Playback ended naturally at the last chunk.
  bool get isCompleted => status == TtsStatus.completed;

  /// The engine reported a failure.
  bool get hasError => status == TtsStatus.error;

  // ─── Computed: progress helpers ───────────────────────────────────────────

  /// [progressFraction] clamped strictly to [0.0, 1.0].
  double get safeProgress => progressFraction.clamp(0.0, 1.0);

  /// `"3 / 42"` style label for chunk position display.
  String get formattedChunkProgress {
    if (totalChunks == 0) return '';
    return '${currentChunk + 1} / $totalChunks';
  }

  /// Integer percentage (0–100) for compact progress displays.
  int get progressPercent => (safeProgress * 100).round();

  /// Whether any meaningful progress value is available.
  bool get hasProgress => progressFraction > 0 && totalChunks > 0;

  // ─── Computed: language helpers ───────────────────────────────────────────

  /// `true` when the current article is in Bengali.
  bool get isBengali => language.toLowerCase().startsWith('bn');

  /// `true` when the current article is in English.
  bool get isEnglish => language.toLowerCase().startsWith('en');

  // ─── copyWith ─────────────────────────────────────────────────────────────

  TtsState copyWith({
    TtsStatus? status,
    int? currentChunk,
    int? totalChunks,
    double? progressFraction,
    String? language,
    TtsConfig? config,
    Duration? estimatedPosition,
    Object? error = _unsetError,
  }) {
    return TtsState(
      status: status ?? this.status,
      currentChunk: currentChunk ?? this.currentChunk,
      totalChunks: totalChunks ?? this.totalChunks,
      progressFraction: (progressFraction ?? this.progressFraction).clamp(
        0.0,
        1.0,
      ),
      language: language ?? this.language,
      config: config ?? this.config,
      estimatedPosition: estimatedPosition ?? this.estimatedPosition,
      error: identical(error, _unsetError) ? this.error : error as String?,
    );
  }

  // ─── Equality ─────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          currentChunk == other.currentChunk &&
          totalChunks == other.totalChunks &&
          progressFraction == other.progressFraction &&
          language == other.language &&
          config == other.config &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
    status,
    currentChunk,
    totalChunks,
    progressFraction,
    language,
    config,
    error,
  );

  @override
  String toString() =>
      'TtsState($status, chunk: $currentChunk/$totalChunks, '
      '$progressPercent%, lang: $language'
      '${error != null ? ', error: "$error"' : ''})';
}
