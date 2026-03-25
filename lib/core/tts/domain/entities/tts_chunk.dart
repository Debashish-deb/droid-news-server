class TtsChunk {
  TtsChunk({
    required this.index,
    required this.text,
    required this.estimatedDuration,
    this.metadata = const {},
    this.isTitleChunk = false,
    this.isAuthorChunk = false,
    this.paragraphIndex = 0,
    this.sentenceIndexInParagraph = 0,
  });
  final int index;
  final String text;
  final Duration estimatedDuration;
  final Map<String, dynamic> metadata;
  final bool isTitleChunk;
  final bool isAuthorChunk;
  final int paragraphIndex;
  final int sentenceIndexInParagraph;
}
