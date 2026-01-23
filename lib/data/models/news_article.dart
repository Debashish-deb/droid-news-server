import 'package:hive/hive.dart';
import 'package:webfeed_revised/webfeed_revised.dart';

part 'news_article.g.dart';

@HiveType(typeId: 0)
class NewsArticle extends HiveObject {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final String description;

  @HiveField(2)
  final String url;

  @HiveField(3)
  final String source;

  @HiveField(4)
  final String? imageUrl;

  @HiveField(5)
  final String language;

  @HiveField(6)
  final String snippet;

  @HiveField(7)
  final String fullContent;

  @HiveField(8)
  final DateTime publishedAt;

  @HiveField(9)
  final bool isLive;

  @HiveField(10)
  String? sourceOverride;

  @HiveField(11)
  String? sourceLogo;

  @HiveField(12)
  bool fromCache; // ✅ Add cache flag

  NewsArticle({
    required this.title,
    this.description = '',
    required this.url,
    required this.source,
    this.imageUrl,
    this.language = 'en',
    this.snippet = '',
    this.fullContent = '',
    required this.publishedAt,
    this.isLive = false,
    this.sourceOverride,
    this.sourceLogo,
    this.fromCache = false, // ✅ default false
  });

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

  factory NewsArticle.fromAtomItem(AtomItem item) {
    // Extract image from media or content
    String? imageUrl;
    if (item.media?.thumbnails?.isNotEmpty ?? false) {
      imageUrl = item.media!.thumbnails!.first.url;
    } else if (item.media?.contents?.isNotEmpty ?? false) {
      imageUrl = item.media!.contents!.first.url;
    } else if (item.content != null) {
      imageUrl = _extractImageFromHtml(item.content!);
    }

    return NewsArticle(
      title: item.title ?? '',
      description: item.summary ?? '',
      url: item.links?.firstOrNull?.href ?? '',
      source: item.source?.title ?? '',
      imageUrl: imageUrl,
      language: 'en',
      publishedAt: (item.updated as DateTime?) ?? (item.published as DateTime?) ?? DateTime.now(),
    );
  }

  factory NewsArticle.fromMap(Map<String, dynamic> map) => NewsArticle(
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
        sourceOverride: map['sourceOverride'],
        sourceLogo: map['sourceLogo'],
        fromCache: map['fromCache'] ?? false, // ✅ support map
      );

  Map<String, dynamic> toMap() => {
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
        'sourceOverride': sourceOverride,
        'sourceLogo': sourceLogo,
        'fromCache': fromCache, // ✅ include in export
      };

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
