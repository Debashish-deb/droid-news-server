import '../../../domain/entities/news_article.dart';

enum InteractionTypeV2 {
  open,
  readDuration,
  searchSubmit,
  suggestionClick,
  bookmark,
  share,
  dismiss,
  wrongLabel,
}

enum FeedbackReason { dismiss, wrongLabel }

class LearningEvent {
  const LearningEvent({
    required this.type,
    required this.timestamp,
    this.article,
    this.query,
    this.topic,
    this.durationSeconds,
    this.reason,
  });

  final InteractionTypeV2 type;
  final DateTime timestamp;
  final NewsArticle? article;
  final String? query;
  final String? topic;
  final int? durationSeconds;
  final FeedbackReason? reason;
}
