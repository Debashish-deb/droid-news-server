import 'package:hive/hive.dart';
import 'package:webfeed_revised/webfeed_revised.dart';
import '../../domain/entities/news_article.dart';

part 'news_article.g.dart';

@HiveType(typeId: 0)
class NewsArticleModel extends HiveObject {

  NewsArticleModel({
    required this.title,
    required this.url, required this.source, required this.publishedAt, this.description = '',
    this.imageUrl,
    this.language = 'en',
    this.snippet = '',
    this.fullContent = '',
    this.isLive = false,
    this.sourceOverride,
    this.sourceLogo,
    this.fromCache = false,
  });

  factory NewsArticleModel.fromDomain(NewsArticle entity) => NewsArticleModel(
        title: entity.title,
        description: entity.description,
        url: entity.url,
        source: entity.source,
        imageUrl: entity.imageUrl,
        language: entity.language,
        snippet: entity.snippet,
        fullContent: entity.fullContent,
        publishedAt: entity.publishedAt,
        isLive: entity.isLive,
        sourceOverride: entity.sourceOverride,
        sourceLogo: entity.sourceLogo,
        fromCache: entity.fromCache,
      );

  factory NewsArticleModel.fromRssItem(RssItem item) {
    final String? mediaUrl = item.media?.thumbnails?.firstOrNull?.url ??
        item.media?.contents?.firstOrNull?.url ??
        _extractImageFromEnclosure(item) ??
        _extractImageFromContent(item.content?.value) ??
        _extractImageFromContent(item.description);

    return NewsArticleModel(
      title: item.title ?? '',
      description: _cleanDescription(item.description ?? ''),
      url: item.link ?? '',
      source: item.source?.value ?? '',
      imageUrl: mediaUrl,
      language: item.dc?.language ?? 'en',
      publishedAt: item.pubDate ?? DateTime.now(),
    );
  }

  factory NewsArticleModel.fromAtomItem(AtomItem item) {
    String? imageUrl;
    if (item.media?.thumbnails?.isNotEmpty ?? false) {
      imageUrl = item.media!.thumbnails!.first.url;
    } else if (item.media?.contents?.isNotEmpty ?? false) {
      imageUrl = item.media!.contents!.first.url;
    } else if (item.content != null) {
      imageUrl = _extractImageFromContent(item.content);
    }

    return NewsArticleModel(
      title: item.title ?? '',
      description: _cleanDescription(item.summary ?? ''),
      url: item.links?.firstOrNull?.href ?? '',
      source: item.source?.title ?? '',
      imageUrl: imageUrl,
      publishedAt: item.updated ?? (item.published as DateTime?) ?? DateTime.now(),
    );
  }

  factory NewsArticleModel.fromMap(Map<String, dynamic> map) => NewsArticleModel(
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
        fromCache: map['fromCache'] ?? false,
      );
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
  bool fromCache;

  NewsArticle toDomain() => NewsArticle(
        title: title,
        description: description,
        url: url,
        source: source,
        imageUrl: imageUrl,
        language: language,
        snippet: snippet,
        fullContent: fullContent,
        publishedAt: publishedAt,
        isLive: isLive,
        sourceOverride: sourceOverride,
        sourceLogo: sourceLogo,
        fromCache: fromCache,
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
        'fromCache': fromCache,
      };

  static String? _extractImageFromEnclosure(RssItem item) {
    final url = item.enclosure?.url ?? '';
    // Basic check for image extensions
    if (url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png') || url.endsWith('.webp')) {
      return url;
    }
    // Some feeds have type="image/jpeg"
    if (item.enclosure?.type?.startsWith('image/') ?? false) {
      return url;
    }
    return null;
  }

  static String? _extractImageFromContent(String? html) {
    if (html == null || html.isEmpty) return null;

    // 1. Try to find Open Graph image (often high quality)
    final RegExp ogImage = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"', caseSensitive: false);
    final matchOg = ogImage.firstMatch(html);
    if (matchOg != null) {
      return matchOg.group(1);
    }
    
    // 2. Find the first img tag
    final RegExp imgTag = RegExp(r'<img[^>]+>', caseSensitive: false);
    final Match? match = imgTag.firstMatch(html);
    
    if (match != null) {
      final String imgHtml = match.group(0)!;

      // a. Check for encoded content in explicit 'data-src' or 'data-original' (lazy loading)
      final RegExp dataSrcRegex = RegExp(r'(data-src|data-original)="([^"]+)"', caseSensitive: false);
      final matchDataSrc = dataSrcRegex.firstMatch(imgHtml);
      if (matchDataSrc != null) {
        return matchDataSrc.group(2);
      }

      // b. Check for srcset to get the largest image
      final RegExp srcsetRegex = RegExp(r'srcset="([^"]+)"', caseSensitive: false);
      final matchSrcset = srcsetRegex.firstMatch(imgHtml);
      if (matchSrcset != null) {
        final String srcset = matchSrcset.group(1)!;
        // Split by comma+space not inside quotes? Usually simple comma is enough for RSS html.
        final List<String> variants = srcset.split(',');
        if (variants.isNotEmpty) {
           // Parse the last variant which is usually the largest "url 1024w" or just "url"
           final String lastVariant = variants.last.trim();
           // Split by space to get URL part
           final parts = lastVariant.split(' ');
           if (parts.isNotEmpty) {
             return parts.first;
           }
        }
      }

      // c. Fallback to standard src
      final RegExp srcRegex = RegExp(r'src="([^"]+)"', caseSensitive: false);
      final matchSrc = srcRegex.firstMatch(imgHtml);
      return matchSrc?.group(1);
    }
    
    return null;
  }

  static String _cleanDescription(String html) {
    // Remove HTML tags to get clean description text
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true);
    var text = html.replaceAll(exp, '').trim();
    // Decode HTML entities if needed (basic ones)
    text = text.replaceAll('&nbsp;', ' ')
               .replaceAll('&amp;', '&')
               .replaceAll('&lt;', '<')
               .replaceAll('&gt;', '>')
               .replaceAll('&quot;', '"');
    return text.length > 200 ? '${text.substring(0, 200)}...' : text;
  }
}
