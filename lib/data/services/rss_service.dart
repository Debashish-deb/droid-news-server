import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for compute
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed_revised/webfeed_revised.dart';
import 'package:http/io_client.dart';
import '../../core/security/ssl_pinning.dart';
import '../../core/utils/retry_helper.dart';
import '../../core/services/app_network_service.dart'; // Unified network service
import '../models/news_article.dart';

class RssService {
  RssService({http.Client? client})
    : _client = client ?? IOClient(SSLPinning.getSecureHttpClient());
  final http.Client _client;

  /// Categories your HomeScreen expects
  static const List<String> categories = <String>[
    'latest',
    'national',
    'international',
    'magazine', // Added implicit support
    'sports',
    'entertainment',
    'technology',
    'economy',
  ];

  static const Map<String, Map<String, List<String>>>
  _feeds = <String, Map<String, List<String>>>{
    'latest': <String, List<String>>{
      'bn': <String>[
        'https://feeds.bbci.co.uk/bengali/rss.xml', // BBC Bangla - 421 articles WITH images ✅
      ],
      'en': <String>[
        'https://feeds.bbci.co.uk/news/world/rss.xml', // BBC World - 36 articles ✅
        'https://www.thedailystar.net/frontpage/rss.xml', // Daily Star frontpage
        'https://bdnews24.com/rss', // BDNews24 main feed
      ],
    },
    'national': <String, List<String>>{
      'bn': <String>[
        'https://www.bd-pratidin.com/rss.xml',
        'https://www.samakal.com/feed', // Added Samakal
        'https://www.ittefaq.com.bd/feed', // Added Ittefaq
        'https://feeds.bbci.co.uk/bengali/rss.xml', // BBC Bangla
      ],
      'en': <String>[
        'https://www.dhakatribune.com/feed',
        'https://bdnews24.com/en/rss/en/bangladesh/rss.xml',
        'https://www.observerbd.com/feed', // Added Observer BD
      ],
    },
    'international': <String, List<String>>{
      'bn': <String>['https://feeds.bbci.co.uk/bengali/world/rss.xml'],
      'en': <String>['https://feeds.bbci.co.uk/news/world/rss.xml'],
    },
    'sports': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/sports/feed',
        'https://www.kalerkantho.com/rss.xml', // General feed includes sports
      ],
      'en': <String>[
        'https://www.dhakatribune.com/sport/feed',
        'https://feeds.bbci.co.uk/sport/rss.xml', // BBC Sports
        'https://bdnews24.com/en/rss/en/sports/rss.xml',
      ],
    },
    'technology': <String, List<String>>{
      'bn': <String>['https://www.prothomalo.com/technology/feed'],
      'en': <String>[
        'https://www.dhakatribune.com/tech/feed',
        'https://feeds.bbci.co.uk/news/technology/rss.xml', // BBC Tech
        'https://techcrunch.com/feed/', // International tech news
      ],
    },
    'entertainment': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/entertainment/feed',
        'https://www.kalerkantho.com/rss.xml', // General feed includes entertainment
      ],
      'en': <String>[
        'https://www.dhakatribune.com/entertainment/feed',
        'https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml', // BBC Entertainment
      ],
    },
    'economy': <String, List<String>>{
      'bn': <String>['https://www.prothomalo.com/business/feed'],
      'en': <String>[
        'https://www.dhakatribune.com/business/feed',
        'https://bdnews24.com/en/rss/en/economy/rss.xml',
        'https://feeds.bbci.co.uk/news/business/rss.xml', // BBC Business
      ],
    },
  };

  Future<List<NewsArticle>> fetchNews({
    required String category,
    required Locale locale,
    BuildContext? context,
    bool preferRss = false,
  }) async {
    // Basic validation, though we might want to allow dynamic categories
    // if (!categories.contains(category)) { ... }

    final String lang = locale.languageCode == 'bn' ? 'bn' : 'en';
    final List<String> urls = _feeds[category]?[lang] ?? const <String>[];

    if (urls.isEmpty) return <NewsArticle>[];

    final List<NewsArticle> all = <NewsArticle>[];

    try {
      final List<List<NewsArticle>> results = await Future.wait(
        urls.map(
          (String url) =>
              _fetchSingleFeed(url: url, category: category, context: context),
        ),
      );

      for (final List<NewsArticle> list in results) {
        all.addAll(list);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching bulk news: $e');
      }
    }

    // Deduplicate by URL
    final Set<String> seen = <String>{};
    final List<NewsArticle> deduped =
        all.where((NewsArticle a) => seen.add(a.url)).toList();

    // Sort newest first
    deduped.sort(
      (NewsArticle a, NewsArticle b) => b.publishedAt.compareTo(a.publishedAt),
    );

    return deduped;
  }

  Future<List<NewsArticle>> _fetchSingleFeed({
    required String url,
    required String category,
    BuildContext? context,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Fetching RSS feed: $url');
      }

      // 🌐 ADAPTIVE TIMEOUT: Critical for Bangladesh networks
      // WiFi: 10s, 4G: 15s, 3G: 25s, 2G: 40s
      final Duration timeout = AppNetworkService().getAdaptiveTimeout();

      // Wrap HTTP request with retry logic
      final http.Response res = await RetryHelper.retry(
        operation: () async {
          final http.Response response = await _client.get(
            Uri.parse(url),
            headers: <String, String>{
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
              'Accept':
                  'application/rss+xml, application/xml, text/xml, */*',
            },
          ).timeout(timeout);
          return response;
        },
        delayDuration: const Duration(seconds: 2),
      );

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('⚠️ RSS feed returned ${res.statusCode} for $url');
        }
        return <NewsArticle>[];
      }

      // Log content type for debugging
      final String? contentType = res.headers['content-type'];
      if (kDebugMode) {
        debugPrint('   Content-Type: $contentType');
      }

      // Try to respect charset if provided
      final String? ct = res.headers['content-type'];
      final String charset = ct?.split('charset=').last ?? 'utf-8';
      final String body =
          Encoding.getByName(charset)?.decode(res.bodyBytes) ??
          utf8.decode(res.bodyBytes);

      // Validate that response looks like XML/RSS
      final bodyTrimmed = body.trim();
      if (!bodyTrimmed.startsWith('<?xml') &&
          !bodyTrimmed.startsWith('<rss') &&
          !bodyTrimmed.startsWith('<feed')) {
        if (kDebugMode) {
          debugPrint('⚠️ Invalid RSS from $url - not XML/RSS format');
          debugPrint(
            '   First 100 chars: ${bodyTrimmed.substring(0, bodyTrimmed.length > 100 ? 100 : bodyTrimmed.length)}',
          );
        }
        return <NewsArticle>[];
      }

      return await compute(_parseRssInBackground, body);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to fetch RSS feed after retries: $url - $e');
      }
      return <NewsArticle>[];
    }
  }

  // ⚡️ ISOLATE FUNCTION (Must be top-level or static)
  static List<NewsArticle> _parseRssInBackground(String xmlBody) {
    try {
      // Try RSS first
      try {
        final RssFeed feed = RssFeed.parse(xmlBody);
        final articles =
            feed.items
                ?.map(NewsArticle.fromRssItem)
                .where(
                  (NewsArticle a) => a.title.isNotEmpty && a.url.isNotEmpty,
                )
                .toList() ??
            <NewsArticle>[];
        if (kDebugMode) {
          debugPrint('✅ Parsed ${articles.length} articles from RSS feed');
        }
        return articles;
      } catch (_) {
        // Try Atom format
        if (kDebugMode) {
          debugPrint('   RSS parse failed, attempting Atom format...');
        }
        final AtomFeed feed = AtomFeed.parse(xmlBody);
        final articles =
            feed.items
                ?.map(NewsArticle.fromAtomItem)
                .where(
                  (NewsArticle a) => a.title.isNotEmpty && a.url.isNotEmpty,
                )
                .toList() ??
            <NewsArticle>[];
        if (kDebugMode) {
          debugPrint('✅ Parsed ${articles.length} articles from Atom feed');
        }
        return articles;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('⚠️ Error parsing feed in isolate: $e');
        debugPrint(
          '   Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
        );
        debugPrint(
          '   XML preview: ${xmlBody.substring(0, xmlBody.length > 200 ? 200 : xmlBody.length)}...',
        );
      }
      return <NewsArticle>[];
    }
  }

  /// Helper map: "id" → logo
  static const Map<String, String> _logoMap = <String, String>{
    // Bangladesh
    'prothomalo': 'prothomalo',
    'jagonews24': 'jagonews24',
    'bdnews24': 'bdnews24',
  };
}
