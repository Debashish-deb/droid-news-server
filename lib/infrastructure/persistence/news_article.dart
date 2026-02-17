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
      title: _cleanTitle(item.title ?? '', item.source?.value ?? ''),
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
      title: _cleanTitle(item.title ?? '', item.source?.title ?? ''),
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
    final RegExp ogImage = RegExp(
      r'<meta\s+(?:property|name)="og:image"\s+content="([^"]+)"',
      caseSensitive: false,
    );
    final matchOg = ogImage.firstMatch(html);
    if (matchOg != null) return matchOg.group(1);

    // 2. Try to find Twitter card image
    final RegExp twitterImage = RegExp(
      r'<meta\s+(?:property|name)="twitter:image(?::src)?"\s+content="([^"]+)"',
      caseSensitive: false,
    );
    final matchTwitter = twitterImage.firstMatch(html);
    if (matchTwitter != null) return matchTwitter.group(1);

    // 3. Find image tags with various source attributes (common in lazy-loading)
    final RegExp imgTag = RegExp(r'<img[^>]+>', caseSensitive: false);
    final matches = imgTag.allMatches(html);

    for (final match in matches) {
      final String imgHtml = match.group(0)!;

      // List of attributes to check for image URL
      final List<String> attributes = [
        'data-src',
        'data-original',
        'data-lazy-src',
        'src',
      ];

      for (final attr in attributes) {
        final RegExp attrRegex = RegExp('$attr="([^"]+)"', caseSensitive: false);
        final attrMatch = attrRegex.firstMatch(imgHtml);
        if (attrMatch != null) {
          final url = attrMatch.group(1)!;
          if (url.startsWith('http') &&
              (url.contains('.jpg') ||
                  url.contains('.jpeg') ||
                  url.contains('.png') ||
                  url.contains('.webp'))) {
            return url;
          }
        }
      }

      // Check for srcset
      final RegExp srcsetRegex = RegExp(r'srcset="([^"]+)"', caseSensitive: false);
      final matchSrcset = srcsetRegex.firstMatch(imgHtml);
      if (matchSrcset != null) {
        final variants = matchSrcset.group(1)!.split(',');
        if (variants.isNotEmpty) {
          final lastVariant = variants.last.trim();
          final parts = lastVariant.split(' ');
          if (parts.isNotEmpty && parts.first.startsWith('http')) {
            return parts.first;
          }
        }
      }
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

  static String _cleanTitle(String title, String source) {
    if (title.isEmpty) return '';
    var cleanTitle = title.trim();

    // 1. Remove trailing source name like " - Dhakapost.com" or " | Dhaka Post"
    // Aggregators like Google News often append this.
    final List<String> separators = [' - ', ' | ', ' – ', ' — '];
    
    for (final sep in separators) {
      if (cleanTitle.contains(sep)) {
        final lastIndex = cleanTitle.lastIndexOf(sep);
        final trailing = cleanTitle.substring(lastIndex + sep.length).toLowerCase();
        final sourceLower = source.toLowerCase();
        
        // If the trailing part matches the source or is a domain-like string
        if (sourceLower.contains(trailing) || 
            trailing.contains(sourceLower) ||
            trailing.contains('.com') || 
            trailing.contains('.net') ||
            trailing.contains('.org')) {
          cleanTitle = cleanTitle.substring(0, lastIndex).trim();
          break;
        }
      }
    }

    // 2. Remove common publication suffixes if source is known
    if (source.isNotEmpty) {
      final sourceNormalized = source.split('.').first.toLowerCase();
      final List<String> suffixes = [
        ' - $source',
        ' | $source',
        ' ($source)',
      ];
      for (final suffix in suffixes) {
        if (cleanTitle.toLowerCase().endsWith(suffix.toLowerCase())) {
          cleanTitle = cleanTitle.substring(0, cleanTitle.length - suffix.length).trim();
        }
      }
    }

    return cleanTitle;
  }
}
