import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Enhanced speech chunk model for industrial-grade TTS
/// 
/// Includes integrity checking, status tracking, and metadata
/// for reliable caching and playback.
class SpeechChunk {

  SpeechChunk({
    required this.id,
    required this.text,
    required this.startIndex,
    required this.endIndex,
    this.language = 'en',
    this.audioPath,
    this.durationMs,
    this.fileSizeBytes,
    this.contentHash,
    this.status = ChunkStatus.pending,
    this.retryCount = 0,
    DateTime? createdAt,
    this.lastModifiedAt,
    this.lastPlayedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SpeechChunk.fromMap(Map<String, dynamic> map) {
    return SpeechChunk(
      id: map['id'] as int,
      text: map['text'] as String,
      startIndex: map['startIndex'] as int,
      endIndex: map['endIndex'] as int,
      language: map['language'] as String? ?? 'en',
      audioPath: map['audioPath'] as String?,
      durationMs: map['durationMs'] as int?,
      fileSizeBytes: map['fileSizeBytes'] as int?,
      contentHash: map['contentHash'] as String?,
      status: map['status'] != null
          ? ChunkStatus.values.firstWhere(
              (s) => s.name == map['status'],
              orElse: () => ChunkStatus.pending,
            )
          : ChunkStatus.pending,
      retryCount: map['retryCount'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      lastModifiedAt: map['lastModifiedAt'] != null
          ? DateTime.parse(map['lastModifiedAt'] as String)
          : null,
      lastPlayedAt: map['lastPlayedAt'] != null
          ? DateTime.parse(map['lastPlayedAt'] as String)
          : null,
    );
  }
  final int id;
  final String text;
  final int startIndex;
  final int endIndex;
  final String language;
  

  String? audioPath; 
  int? durationMs; 
  int? fileSizeBytes;
  

  String? contentHash; 
  ChunkStatus status;
  int retryCount; 
  
 
  final DateTime createdAt;
  DateTime? lastModifiedAt;
  DateTime? lastPlayedAt;
  
  /// Generate content hash from text (for cache key)
  String get textHash {
    final bytes = utf8.encode('$text|$language');
    return sha256.convert(bytes).toString();
  }
  
  /// Check if chunk has valid cached audio
  bool get hasCachedAudio {
    return audioPath != null && 
           contentHash != null &&
           status == ChunkStatus.cached;
  }
  
  /// Check if chunk is ready to play
  bool get isReadyToPlay {
    return status == ChunkStatus.cached || status == ChunkStatus.ready;
  }
  
  /// Check if chunk needs retry
  bool get needsRetry {
    return status == ChunkStatus.error && retryCount < 3;
  }
  
  /// Mark as cached with audio file info
  SpeechChunk markCached({
    required String path,
    required String hash,
    required int duration,
    required int  size,
  }) {
    return copyWith(
      audioPath: path,
      contentHash: hash,
      durationMs: duration,
      fileSizeBytes: size,
      status: ChunkStatus.cached,
      lastModifiedAt: DateTime.now(),
    );
  }
  
  /// Mark as error and increment retry
  SpeechChunk markError() {
    return copyWith(
      status: ChunkStatus.error,
      retryCount: retryCount + 1,
      lastModifiedAt: DateTime.now(),
    );
  }
  
  /// Mark as played
  SpeechChunk markPlayed() {
    return copyWith(
      lastPlayedAt: DateTime.now(),
    );
  }
  
  /// Copy with modifications
  SpeechChunk copyWith({
    int? id,
    String? text,
    int? startIndex,
    int? endIndex,
    String? language,
    String? audioPath,
    int? durationMs,
    int? fileSizeBytes,
    String? contentHash,
    ChunkStatus? status,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    DateTime? lastPlayedAt,
  }) {
    return SpeechChunk(
      id: id ?? this.id,
      text: text ?? this.text,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      language: language ?? this.language,
      audioPath: audioPath ?? this.audioPath,
      durationMs: durationMs ?? this.durationMs,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      contentHash: contentHash ?? this.contentHash,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'startIndex': startIndex,
      'endIndex': endIndex,
      'language': language,
      'audioPath': audioPath,
      'durationMs': durationMs,
      'fileSizeBytes': fileSizeBytes,
      'contentHash': contentHash,
      'status': status.name,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    };
  }
  
  @override
  String toString() {
    return 'SpeechChunk(id: $id, status: $status, '
           'text: "${text.substring(0, text.length.clamp(0, 30))}...")';
  }
}

/// Status of a speech chunk in the TTS pipeline
enum ChunkStatus {
  /// Waiting to be processed
  pending,
  
  /// Currently generating audio
  generating,
  
  /// Audio generated and cached
  cached,
  
  /// Ready to play (loaded in memory)
  ready,
  
  /// Currently playing
  playing,
  
  /// Completed playback
  completed,
  
  /// Error during generation or playback
  error,
  
  /// Skipped (e.g. corrupted, max retries exceeded)
  skipped,
}
