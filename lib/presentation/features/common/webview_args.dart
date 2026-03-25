import '../../../domain/entities/news_article.dart';

enum WebViewOrigin { article, deeplink, notification, publisher, savedArticle }

class WebViewArgs {
  const WebViewArgs({
    required this.url,
    required this.title,
    required this.origin,
    this.articles = const <NewsArticle>[],
    this.initialIndex = 0,
  });

  final Uri url;
  final String title;
  final WebViewOrigin origin;
  final List<NewsArticle> articles;
  final int initialIndex;

  bool get hasFeedContext => articles.isNotEmpty;
}
