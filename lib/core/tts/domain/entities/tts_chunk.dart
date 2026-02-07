class TtsChunk {

  TtsChunk({
    required this.index,
    required this.text,
    required this.estimatedDuration,
    this.metadata = const {},
  });
  final int index;
  final String text;
  final Duration estimatedDuration;
  final Map<String, dynamic> metadata;
}
