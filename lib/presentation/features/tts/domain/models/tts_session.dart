import 'package:flutter/foundation.dart';

/// Represents the state of a TTS reading session
/// 
/// This is the core domain model that tracks everything about
/// an active or saved TTS session for resumability and state management.
@immutable
class TtsSession {
  
  const TtsSession({
    required this.sessionId,
    required this.articleId,
    required this.articleTitle,
    required this.createdAt, this.currentChunkIndex = 0,
    this.totalChunks = 0,
    this.playbackPosition = Duration.zero,
    this.retryAttempts = 0,
    this.state = TtsSessionState.idle,
    this.lastActiveAt,
    this.errorMessage,
  });
  
  /// Create a new session for an article
  factory TtsSession.create({
    required String articleId,
    required String articleTitle,
  }) {
    final now = DateTime.now();
    return TtsSession(
      sessionId: '${articleId}_${now.millisecondsSinceEpoch}',
      articleId: articleId,
      articleTitle: articleTitle,
      createdAt: now,
      lastActiveAt: now,
    );
  }
  
  /// Create from Map (persistence)
  factory TtsSession.fromJson(Map<String, dynamic> json) {
    return TtsSession(
      sessionId: json['sessionId'] as String,
      articleId: json['articleId'] as String,
      articleTitle: json['articleTitle'] as String,
      currentChunkIndex: json['currentChunkIndex'] as int? ?? 0,
      totalChunks: json['totalChunks'] as int? ?? 0,
      playbackPosition: Duration(
        milliseconds: json['playbackPositionMs'] as int? ?? 0,
      ),
      retryAttempts: json['retryAttempts'] as int? ?? 0,
      state: TtsSessionState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => TtsSessionState.idle,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: json['lastActiveAt'] != null 
          ? DateTime.parse(json['lastActiveAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
  final String sessionId;
  final String articleId;
  final String articleTitle;
  final int currentChunkIndex;
  final int totalChunks;
  final Duration playbackPosition;
  final int retryAttempts;
  final TtsSessionState state;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final String? errorMessage;
  
  /// Copy with modifications
  TtsSession copyWith({
    String? sessionId,
    String? articleId,
    String? articleTitle,
    int? currentChunkIndex,
    int? totalChunks,
    Duration? playbackPosition,
    int? retryAttempts,
    TtsSessionState? state,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? errorMessage,
  }) {
    return TtsSession(
      sessionId: sessionId ?? this.sessionId,
      articleId: articleId ?? this.articleId,
      articleTitle: articleTitle ?? this.articleTitle,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  /// Increment chunk index
  TtsSession nextChunk() {
    return copyWith(
      currentChunkIndex: currentChunkIndex + 1,
      playbackPosition: Duration.zero,
      lastActiveAt: DateTime.now(),
    );
  }
  
  /// Go to previous chunk
  TtsSession previousChunk() {
    return copyWith(
      currentChunkIndex: (currentChunkIndex - 1).clamp(0, totalChunks - 1),
      playbackPosition: Duration.zero,
      lastActiveAt: DateTime.now(),
    );
  }
  
  /// Mark as error with retry increment
  TtsSession markError(String error) {
    return copyWith(
      state: TtsSessionState.error,
      errorMessage: error,
      retryAttempts: retryAttempts + 1,
      lastActiveAt: DateTime.now(),
    );
  }
  
  /// Reset retry count (successful recovery)
  TtsSession resetRetries() {
    return copyWith(retryAttempts: 0);
  }
  
  /// Check if session is resumable
  bool get isResumable {
    return currentChunkIndex > 0 && 
           currentChunkIndex < totalChunks &&
           state != TtsSessionState.error;
  }
  
  /// Check if session is complete
  bool get isComplete {
    return currentChunkIndex >= totalChunks - 1 && 
           state == TtsSessionState.completed;
  }
  
  /// Progress percentage (0.0 - 1.0)
  double get progress {
    if (totalChunks == 0) return 0.0;
    return (currentChunkIndex / totalChunks).clamp(0.0, 1.0);
  }
  
  /// Convert to Map for persistence
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'articleId': articleId,
      'articleTitle': articleTitle,
      'currentChunkIndex': currentChunkIndex,
      'totalChunks': totalChunks,
      'playbackPositionMs': playbackPosition.inMilliseconds,
      'retryAttempts': retryAttempts,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }
  
  @override
  String toString() {
    return 'TtsSession(id: $sessionId, article: $articleTitle, '
           'chunk: $currentChunkIndex/$totalChunks, state: $state)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsSession && other.sessionId == sessionId;
  }
  
  @override
  int get hashCode => sessionId.hashCode;
}

/// State machine for TTS sessions
/// 
/// Represents all possible states a TTS session can be in,
/// with clear transitions and error recovery paths.
enum TtsSessionState {
  /// Initial state, nothing loaded
  idle,
  
  /// Loading article, preparing for chunking
  preparing,
  
  /// Chunking text into speech segments
  chunking,
  
  /// Generating audio for chunks
  generating,
  
  /// Buffering next chunks
  buffering,
  
  /// Actively playing audio
  playing,
  
  /// Playback paused by user
  paused,
  
  /// Error occurred, attempting recovery
  error,
  
  /// Auto-recovering from error
  recovering,
  
  /// All chunks played successfully
  completed,
  
  /// User stopped playback
  stopped,
}

/// Extension methods for state transitions
extension TtsSessionStateExtension on TtsSessionState {
  /// Check if state allows playback
  bool get canPlay {
    return this == TtsSessionState.paused || 
           this == TtsSessionState.buffering ||
           this == TtsSessionState.completed;
  }
  
  /// Check if state allows pause
  bool get canPause {
    return this == TtsSessionState.playing;
  }
  
  /// Check if in a loading/busy state
  bool get isLoading {
    return this == TtsSessionState.preparing ||
           this == TtsSessionState.chunking ||
           this == TtsSessionState.generating ||
           this == TtsSessionState.buffering;
  }
  
  /// Check if in error state
  bool get isError {
    return this == TtsSessionState.error;
  }
  
  /// Check if actively playing
  bool get isPlaying {
    return this == TtsSessionState.playing;
  }
}
