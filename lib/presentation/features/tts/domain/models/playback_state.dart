import 'package:flutter/foundation.dart';
import 'tts_session.dart';

// Represents the current playback state for UI synchronization
// 
// This is the reactive model that UI widgets observe to update
// their display in real-time as playback progresses.
@immutable
class TtsPlaybackState {
  
  const TtsPlaybackState({
    required this.lastUpdated, this.session,
    this.state = TtsSessionState.idle,
    this.currentChunkIndex = 0,
    this.totalChunks = 0,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.playbackSpeed = 1.0,
    this.errorMessage,
  });
  
  factory TtsPlaybackState.initial() {
    return TtsPlaybackState(
      lastUpdated: DateTime.now(),
    );
  }
  

  factory TtsPlaybackState.fromSession(TtsSession session) {
    return TtsPlaybackState(
      session: session,
      state: session.state,
      currentChunkIndex: session.currentChunkIndex,
      totalChunks: session.totalChunks,
      currentPosition: session.playbackPosition,
      lastUpdated: DateTime.now(),
    );
  }
  final TtsSession? session;
  final TtsSessionState state;
  final int currentChunkIndex;
  final int totalChunks;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackSpeed;
  final String? errorMessage;
  final DateTime lastUpdated;
  

  TtsPlaybackState copyWith({
    TtsSession? session,
    TtsSessionState? state,
    int? currentChunkIndex,
    int? totalChunks,
    Duration? currentPosition,
    Duration? totalDuration,
    double? playbackSpeed,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return TtsPlaybackState(
      session: session ?? this.session,
      state: state ?? this.state,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
  

  bool get isPlaying {
    return state == TtsSessionState.playing;
  }
  

  bool get isPaused {
    return state == TtsSessionState.paused;
  }
  

  bool get isLoading {
    return state.isLoading;
  }
  
  bool get hasError {
    return state == TtsSessionState.error && errorMessage != null;
  }
  
  bool get hasStarted {
    return currentChunkIndex > 0 || 
           state == TtsSessionState.playing ||
           state == TtsSessionState.paused;
  }
  
  bool get isComplete {
    return state == TtsSessionState.completed ||
           (currentChunkIndex >= totalChunks - 1 && totalChunks > 0);
  }
  
  double get progress {
    if (totalChunks == 0) return 0.0;
    return (currentChunkIndex / totalChunks).clamp(0.0, 1.0);
  }
  

  Duration get estimatedTimeRemaining {
    if (totalDuration == Duration.zero || currentPosition >= totalDuration) {
      return Duration.zero;
    }
    final remaining = totalDuration - currentPosition;
 
    return Duration(
      milliseconds: (remaining.inMilliseconds / playbackSpeed).round(),
    );
  }
  

  String get formattedPosition {
    return _formatDuration(currentPosition);
  }
  

  String get formattedDuration {
    return _formatDuration(totalDuration);
  }
  
 
  String get formattedProgress {
    return '${currentChunkIndex + 1} $totalChunks';
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsPlaybackState && 
           other.state == state &&
           other.currentChunkIndex == currentChunkIndex &&
           other.totalChunks == totalChunks &&
           other.currentPosition == currentPosition &&
           other.playbackSpeed == playbackSpeed;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      state,
      currentChunkIndex,
      totalChunks,
      currentPosition,
      playbackSpeed,
    );
  }
  
  @override
  String toString() {
    return 'TtsPlaybackState('
           'state: $state, '
           'chunk: $currentChunkIndex/$totalChunks, '
           'position: $formattedPosition, '
           'speed: ${playbackSpeed}x'
           ')';
  }
}
