import '../../../domain/entities/news_article.dart';

/// Navigation payload for opening a news detail screen with feed context.
///
/// [articles] + [initialIndex] let detail-level controls move between
/// neighboring feed articles.
class NewsDetailArgs {
  const NewsDetailArgs({
    required this.article,
    required this.articles,
    required this.initialIndex,
  });

  final NewsArticle article;
  final List<NewsArticle> articles;
  final int initialIndex;
}

