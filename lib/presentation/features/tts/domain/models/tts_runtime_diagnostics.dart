import 'package:flutter/foundation.dart';

enum TtsRuntimePhase {
  idle,
  initializing,
  preparing,
  synthesizing,
  playing,
  paused,
  stopped,
  error,
}

@immutable
class TtsRuntimeDiagnostics {
  const TtsRuntimeDiagnostics({
    this.phase = TtsRuntimePhase.idle,
    this.message,
    this.lastError,
    this.articleId,
    this.articleTitle,
    this.chunkIndex,
    this.totalChunks,
    this.requestedOutputPath,
    this.resolvedOutputPath,
    this.synthesisStrategy,
    this.usedCachedAudio,
    this.updatedAt,
  });

  static const Object _unset = Object();

  final TtsRuntimePhase phase;
  final String? message;
  final String? lastError;
  final String? articleId;
  final String? articleTitle;
  final int? chunkIndex;
  final int? totalChunks;
  final String? requestedOutputPath;
  final String? resolvedOutputPath;
  final String? synthesisStrategy;
  final bool? usedCachedAudio;
  final DateTime? updatedAt;

  bool get hasError => (lastError ?? '').trim().isNotEmpty;

  String? get chunkLabel {
    final index = chunkIndex;
    final total = totalChunks;
    if (index == null || index < 0) return null;
    if (total == null || total <= 0) return 'Part ${index + 1}';
    return 'Part ${index + 1} of $total';
  }

  TtsRuntimeDiagnostics copyWith({
    TtsRuntimePhase? phase,
    Object? message = _unset,
    Object? lastError = _unset,
    Object? articleId = _unset,
    Object? articleTitle = _unset,
    Object? chunkIndex = _unset,
    Object? totalChunks = _unset,
    Object? requestedOutputPath = _unset,
    Object? resolvedOutputPath = _unset,
    Object? synthesisStrategy = _unset,
    Object? usedCachedAudio = _unset,
    Object? updatedAt = _unset,
  }) {
    return TtsRuntimeDiagnostics(
      phase: phase ?? this.phase,
      message: identical(message, _unset) ? this.message : message as String?,
      lastError: identical(lastError, _unset)
          ? this.lastError
          : lastError as String?,
      articleId: identical(articleId, _unset)
          ? this.articleId
          : articleId as String?,
      articleTitle: identical(articleTitle, _unset)
          ? this.articleTitle
          : articleTitle as String?,
      chunkIndex: identical(chunkIndex, _unset)
          ? this.chunkIndex
          : chunkIndex as int?,
      totalChunks: identical(totalChunks, _unset)
          ? this.totalChunks
          : totalChunks as int?,
      requestedOutputPath: identical(requestedOutputPath, _unset)
          ? this.requestedOutputPath
          : requestedOutputPath as String?,
      resolvedOutputPath: identical(resolvedOutputPath, _unset)
          ? this.resolvedOutputPath
          : resolvedOutputPath as String?,
      synthesisStrategy: identical(synthesisStrategy, _unset)
          ? this.synthesisStrategy
          : synthesisStrategy as String?,
      usedCachedAudio: identical(usedCachedAudio, _unset)
          ? this.usedCachedAudio
          : usedCachedAudio as bool?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}
