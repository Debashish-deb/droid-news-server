class SpeechChunk {
  final int id;
  final String text;
  final int startIndex;
  final int endIndex;
  final String language;
  String? audioPath; // Cached file path
  int? durationMs;

  SpeechChunk({
    required this.id,
    required this.text,
    required this.startIndex,
    required this.endIndex,
    this.language = 'en',
    this.audioPath,
    this.durationMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'startIndex': startIndex,
      'endIndex': endIndex,
      'language': language,
      'audioPath': audioPath,
      'durationMs': durationMs,
    };
  }

  factory SpeechChunk.fromMap(Map<String, dynamic> map) {
    return SpeechChunk(
      id: map['id'],
      text: map['text'],
      startIndex: map['startIndex'],
      endIndex: map['endIndex'],
      language: map['language'] ?? 'en',
      audioPath: map['audioPath'],
      durationMs: map['durationMs'],
    );
  }
}
