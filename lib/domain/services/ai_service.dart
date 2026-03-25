enum SummaryType { tldr, keyPoints, detailed }

///trending topic with metadata.
class ExtractedTopic {
  const ExtractedTopic({
    required this.label,
    required this.frequency,
    this.sourceArticleUrls = const [],
  });
  final String label;
  final int frequency;
  final List<String> sourceArticleUrls;
}

/// Service responsible for AI operations (Summarization, Tagging, Trending, Explaining)
abstract class AIService {
  Future<String> summarize(
    String content, {
    SummaryType type = SummaryType.detailed,
  });
  Future<String> explainComplexTerm(String term, String context);
  Future<List<String>> generateTags(String content);

  List<ExtractedTopic> extractTrendingTopics(
    List<Map<String, String>> articles,
  );

  Future<String> summarizeArticle(String content);
}
