import 'package:equatable/equatable.dart';
import 'news_article.dart';

/// Represents a cluster of related news articles (a "Thread").
/// 
/// Instead of showing 5 duplicate stories about the same event,
/// we show 1 [NewsThread] with a [mainArticle] and multiple [relatedArticles].
class NewsThread extends Equatable {

  const NewsThread({
    required this.id,
    required this.mainArticle,
    this.relatedArticles = const [],
    this.coherenceScore = 1.0,
    this.keywords = const [],
  });

  /// Creates a single-article thread (wrapper).
  factory NewsThread.fromArticle(NewsArticle article) {
    return NewsThread(
      id: 'thread_${article.url.hashCode}',
      mainArticle: article,
    );
  }
  /// Unique ID for this thread (derived from the main article).
  final String id;

  /// The most representative article of the cluster.
  final NewsArticle mainArticle;

  /// Other articles that are semantically similar to the main article.
  final List<NewsArticle> relatedArticles;

  /// How "tight" this cluster is (0.0 to 1.0).
  final double coherenceScore;

  /// The keywords that define this cluster.
  final List<String> keywords;

  @override
  List<Object?> get props => [id, mainArticle, relatedArticles, coherenceScore, keywords];
}
