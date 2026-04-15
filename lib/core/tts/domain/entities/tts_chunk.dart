import 'package:flutter/foundation.dart';

/// A single unit of TTS content — one sentence, the article title, or the
/// author credit.
///
/// Chunks form the bridge between the text-processing pipeline and the UI:
/// each chunk maps 1-to-1 with a sentence highlight region in the reader.
@immutable
class TtsChunk {
  const TtsChunk({
    required this.index,
    required this.text,
    required this.estimatedDuration,
    this.metadata = const {},
    this.isTitleChunk = false,
    this.isAuthorChunk = false,
    this.paragraphIndex = 0,
    this.sentenceIndexInParagraph = 0,
  });

  // ─── Core identity ─────────────────────────────────────────────────────────

  /// Zero-based position in the flat chunk list for the current article.
  final int index;

  /// The plain text this chunk represents.
  final String text;

  /// Heuristic playback duration; used for progress estimation only.
  final Duration estimatedDuration;

  // ─── Classification flags ──────────────────────────────────────────────────

  /// `true` when this chunk holds the article title preamble.
  final bool isTitleChunk;

  /// `true` when this chunk holds the author credit preamble.
  final bool isAuthorChunk;

  // ─── Structural position ───────────────────────────────────────────────────

  /// Zero-based paragraph index in the source article body.
  /// `-1` for preamble (title / author) chunks.
  final int paragraphIndex;

  /// Position of this sentence within its paragraph.
  /// `-1` for preamble chunks.
  final int sentenceIndexInParagraph;

  // ─── Arbitrary metadata ────────────────────────────────────────────────────

  /// Extension bag: callers may store tone, language hints, etc.
  final Map<String, dynamic> metadata;

  // ─── Computed helpers ──────────────────────────────────────────────────────

  /// `true` for normal body sentences (not title or author).
  bool get isBodyChunk => !isTitleChunk && !isAuthorChunk;

  /// Whether this chunk belongs to a preamble section.
  bool get isPreamble => isTitleChunk || isAuthorChunk;

  /// `true` when [text] contains no printable content.
  bool get isEmpty => text.trim().isEmpty;

  /// Approximate word count — useful for reading-time displays.
  int get wordCount => text.trim().isEmpty
      ? 0
      : text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  /// Estimated duration in whole seconds, clamped to at least 0.
  int get estimatedSeconds => estimatedDuration.inSeconds.clamp(0, 600);

  /// `true` when this is the first sentence in its paragraph.
  bool get isFirstInParagraph => sentenceIndexInParagraph == 0;

  /// Retrieves a typed value from [metadata], or [defaultValue] when absent.
  T? meta<T>(String key, [T? defaultValue]) =>
      metadata[key] is T ? metadata[key] as T : defaultValue;

  // ─── copyWith ──────────────────────────────────────────────────────────────

  TtsChunk copyWith({
    int? index,
    String? text,
    Duration? estimatedDuration,
    Map<String, dynamic>? metadata,
    bool? isTitleChunk,
    bool? isAuthorChunk,
    int? paragraphIndex,
    int? sentenceIndexInParagraph,
  }) => TtsChunk(
    index: index ?? this.index,
    text: text ?? this.text,
    estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    metadata: metadata ?? this.metadata,
    isTitleChunk: isTitleChunk ?? this.isTitleChunk,
    isAuthorChunk: isAuthorChunk ?? this.isAuthorChunk,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    sentenceIndexInParagraph:
        sentenceIndexInParagraph ?? this.sentenceIndexInParagraph,
  );

  // ─── Equality ──────────────────────────────────────────────────────────────

  /// Two chunks are equal when they occupy the same [index] in the same list.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsChunk &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() {
    final kind = isTitleChunk
        ? 'title'
        : isAuthorChunk
        ? 'author'
        : 'body(p$paragraphIndex:s$sentenceIndexInParagraph)';
    final preview = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    return 'TtsChunk(#$index [$kind] "$preview" ~${estimatedSeconds}s)';
  }
}
