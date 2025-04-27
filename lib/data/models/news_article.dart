// path: lib/data/models/news_article.dart

import 'package:webfeed_revised/webfeed_revised.dart';

class NewsArticle {
  NewsArticle({
    required this.title,
    this.description = '',
    required this.url,
    required this.source,
    this.imageUrl,
    this.language = 'en', // Default to English
    this.snippet = '',
    this.fullContent = '',
    required this.publishedAt,
    this.isLive = false,
  });

  final String title;
  final String description;
  final String url;
  final String source;
  final String? imageUrl;
  final String language;
  final String snippet;
  final String fullContent;
  final DateTime publishedAt;
  final bool isLive;

  /// Create from RSS item
  factory NewsArticle.fromRssItem(RssItem item) {
    final mediaUrl = item.media?.thumbnails?.firstOrNull?.url ??
        item.media?.contents?.firstOrNull?.url ??
        _extractImageFromEnclosure(item) ??
        _extractImageFromHtml(item.content?.value ?? item.description ?? '');

    return NewsArticle(
      title: item.title ?? '',
      description: item.description ?? '',
      url: item.link ?? '',
      source: item.source?.value ?? '',
      imageUrl: mediaUrl,
      language: item.dc?.language ?? 'en',
      publishedAt: item.pubDate ?? DateTime.now(),
    );
  }

  /// Create from Firebase or other JSON Map
  factory NewsArticle.fromMap(Map<String, dynamic> map) {
    return NewsArticle(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      url: map['url'] ?? '',
      source: map['source'] ?? '',
      imageUrl: map['imageUrl'],
      language: map['language'] ?? 'en',
      snippet: map['snippet'] ?? '',
      fullContent: map['fullContent'] ?? '',
      publishedAt: DateTime.tryParse(map['publishedAt'] ?? '') ?? DateTime.now(),
      isLive: map['isLive'] ?? false,
    );
  }

  /// Convert to JSON Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'url': url,
      'source': source,
      'imageUrl': imageUrl,
      'language': language,
      'snippet': snippet,
      'fullContent': fullContent,
      'publishedAt': publishedAt.toIso8601String(),
      'isLive': isLive,
    };
  }

  static String? _extractImageFromEnclosure(RssItem item) {
    final url = item.enclosure?.url ?? '';
    return (url.endsWith('.jpg') || url.endsWith('.png')) ? url : null;
  }

  static String? _extractImageFromHtml(String html) {
    final RegExp imgTag = RegExp(r'<img[^>]+src="([^">]+)"');
    final match = imgTag.firstMatch(html);
    return match?.group(1);
  }
}
