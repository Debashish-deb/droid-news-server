import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed_revised/webfeed_revised.dart';
import '../../core/telemetry/performance_metrics.dart' show PerformanceMetrics;
import '../../core/utils/retry_helper.dart';
import '../network/app_network_service.dart'; 
import '../../domain/entities/news_article.dart';
import '../persistence/news_article.dart'; 

import '../../core/telemetry/structured_logger.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class RssService {

  RssService(
    this._client,
    this._networkService,
    this._logger,
  );
  final http.Client _client;
  final AppNetworkService _networkService;
  final StructuredLogger _logger;


  static const List<String> categories = <String>[
    'latest',
    'national',
    'international',
    'magazine',
    'sports',
    'entertainment',
    'technology',
    'economy',
  ];

  static const Map<String, Map<String, List<String>>>
  _feeds = <String, Map<String, List<String>>>{
    'latest': <String, List<String>>{
      'bn': <String>[
        'https://news.google.com/rss?hl=bn&gl=BD&ceid=BD:bn',
        'https://feeds.bbci.co.uk/bengali/rss.xml',
        'https://www.jugantor.com/feed/rss.xml',
        'https://www.kalbela.com/assets/rss.xml',
        'https://www.banglanews24.com/rss/rss.xml',
      ],
      'en': <String>[
        'https://news.google.com/rss?hl=en-BD&gl=BD&ceid=BD:en',
        'https://feeds.bbci.co.uk/news/world/asia/rss.xml',
        'https://www.thedailystar.net/frontpage/rss.xml',
        'https://bdnews24.com/rss',
        'https://www.newagebd.net/rss.xml',
        'https://thefinancialexpress.com.bd/rss/index.xml',
        'https://www.observerbd.com/feed',
      ],
    },
    'national': <String, List<String>>{
      'bn': <String>[
        'https://www.bd-pratidin.com/rss.xml',
        'https://www.samakal.com/feed', 
        'https://www.ittefaq.com.bd/feed', 
        'https://www.jugantor.com/feed/rss.xml',
        'https://www.jaijaidinbd.com/feed',
      ],
      'en': <String>[
        'https://bdnews24.com/en/rss/en/bangladesh/rss.xml',
        'https://www.observerbd.com/feed', 
        'https://www.daily-sun.com/rss/all-news',
      ],
    },
    'international': <String, List<String>>{
      'bn': <String>[
        'https://feeds.bbci.co.uk/bengali/world/rss.xml',
        'https://www.jugantor.com/feed/international/rss.xml',
      ],
      'en': <String>[
        'https://feeds.bbci.co.uk/news/world/rss.xml',
        'https://www.aljazeera.com/xml/rss/all.xml',
      ],
    },
    'sports': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/sports/feed',
        'https://www.kalerkantho.com/rss.xml', 
        'https://www.jugantor.com/feed/sports/rss.xml',
      ],
      'en': <String>[
        'https://feeds.bbci.co.uk/sport/rss.xml', 
        'https://bdnews24.com/en/rss/en/sports/rss.xml',
      ],
    },
    'technology': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/technology/feed',
        'https://www.jugantor.com/feed/education-technology/rss.xml',
      ],
      'en': <String>[
        'https://feeds.bbci.co.uk/news/technology/rss.xml', 
        'https://techcrunch.com/feed/', 
      ],
    },
    'entertainment': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/entertainment/feed',
        'https://www.kalerkantho.com/rss.xml', 
        'https://www.jugantor.com/feed/entertainment/rss.xml',
      ],
      'en': <String>[
        'https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml',
      ],
    },
    'economy': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/business/feed',
        'https://www.jugantor.com/feed/economics/rss.xml',
      ],
      'en': <String>[
        'https://bdnews24.com/en/rss/en/economy/rss.xml',
        'https://feeds.bbci.co.uk/news/business/rss.xml',
        'https://thefinancialexpress.com.bd/rss/economy/index.xml',
      ],
    },
  };

  Future<List<NewsArticle>> fetchNews({
    required String category,
    required Locale locale,
    BuildContext? context,
    bool preferRss = false,
  }) async {
    final String lang = locale.languageCode == 'bn' ? 'bn' : 'en';
    final List<String> urls = _feeds[category]?[lang] ?? const <String>[];

    if (urls.isEmpty) return <NewsArticle>[];
    if (!_networkService.isConnected) {
      _logger.warn('Skipping RSS fetch: offline');
      return <NewsArticle>[];
    }

    final List<NewsArticle> all = <NewsArticle>[];

    try {
      final List<String> selectedUrls = _selectUrlsForQuality(urls);
      final List<List<NewsArticle>> results = await _fetchFeeds(
        urls: selectedUrls,
        category: category,
        context: context,
      );

      for (final List<NewsArticle> list in results) {
        // Enforce language based on the feed we scraped
        final corrected = list.map((a) => a.copyWith(language: lang)).toList();
        all.addAll(corrected);
      }
    } catch (e) {
      _logger.error('Error fetching bulk news', e);
    }

  
    final Set<String> seen = <String>{};
    final List<NewsArticle> deduped =
        all.where((NewsArticle a) => seen.add(a.url)).toList();

    
    deduped.sort(
      (NewsArticle a, NewsArticle b) => b.publishedAt.compareTo(a.publishedAt),
    );

    return _interleaveArticles(deduped);
  }

  List<String> _selectUrlsForQuality(List<String> urls) {
    final NetworkQuality quality = _networkService.currentQuality;
    final int maxFeeds;

    switch (quality) {
      case NetworkQuality.offline:
      case NetworkQuality.poor:
        maxFeeds = 2;
        break;
      case NetworkQuality.fair:
        maxFeeds = 3;
        break;
      case NetworkQuality.good:
        maxFeeds = 5;
        break;
      case NetworkQuality.excellent:
        maxFeeds = urls.length;
        break;
    }

    return urls.take(maxFeeds).toList();
  }

  Future<List<List<NewsArticle>>> _fetchFeeds({
    required List<String> urls,
    required String category,
    BuildContext? context,
  }) async {
    final NetworkQuality quality = _networkService.currentQuality;
    final bool sequential =
        quality == NetworkQuality.poor || quality == NetworkQuality.offline;

    if (sequential) {
      final List<List<NewsArticle>> results = [];
      for (final url in urls) {
        results.add(
          await _fetchSingleFeed(
            url: url,
            category: category,
            context: context,
          ),
        );
      }
      return results;
    }

    return Future.wait(
      urls.map(
        (String url) =>
            _fetchSingleFeed(url: url, category: category, context: context),
      ),
    );
  }

  List<NewsArticle> _interleaveArticles(List<NewsArticle> articles) {
    if (articles.isEmpty) return [];

    // 1. Group by source
    final Map<String, List<NewsArticle>> bySource = {};
    for (final article in articles) {
      if (!bySource.containsKey(article.source)) {
        bySource[article.source] = [];
      }
      bySource[article.source]!.add(article);
    }

    // 2. Sort each source's articles by date descending
    for (final key in bySource.keys) {
      bySource[key]!.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }

    final List<NewsArticle> result = [];
    String? lastSource;
    int consecutiveCount = 0;

    // 3. Merge sorted lists with constraints
    while (bySource.isNotEmpty) {
      String? bestSource;
      NewsArticle? bestArticle;

      // Find the "freshest" article from allowed sources
      for (final source in bySource.keys) {
        // Constraint: No more than 2 consecutive from same source
        if (source == lastSource && consecutiveCount >= 2) {
          continue;
        }

        final candidate = bySource[source]!.first;
        if (bestArticle == null || candidate.publishedAt.isAfter(bestArticle.publishedAt)) {
          bestArticle = candidate;
          bestSource = source;
        }
      }

      // If we're stuck (e.g. only one source left and we hit the limit), break or force pick?
      // Strict rule: "no more than two". So we break.
      if (bestSource == null) {
        break; 
      }

      // Add to result
      result.add(bestArticle!);
      
      // Update constraints
      if (bestSource == lastSource) {
        consecutiveCount++;
      } else {
        lastSource = bestSource;
        consecutiveCount = 1;
      }

      // Remove from pool
      bySource[bestSource]!.removeAt(0);
      if (bySource[bestSource]!.isEmpty) {
        bySource.remove(bestSource);
      }
    }

    return result;
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

      final Duration timeout = _networkService.getAdaptiveTimeout();
      final metricName = 'RssService.fetch($url)';
      PerformanceMetrics().startTimer(metricName);

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
      );
      
      PerformanceMetrics().stopTimer(metricName, attributes: {'statusCode': res.statusCode});

      if (res.statusCode != 200) {
        _logger.warn('RSS feed returned ${res.statusCode} for $url');
        return <NewsArticle>[];
      }

      final String? ct = res.headers['content-type'];
      final String charset = ct?.split('charset=').last ?? 'utf-8';
      final String body =
          Encoding.getByName(charset)?.decode(res.bodyBytes) ??
          utf8.decode(res.bodyBytes);

      final bodyTrimmed = body.trim();
      if (!bodyTrimmed.startsWith('<?xml') &&
          !bodyTrimmed.startsWith('<rss') &&
          !bodyTrimmed.startsWith('<feed')) {
        return <NewsArticle>[];
      }

      return await compute(_parseRssInBackground, body);
    } catch (e) {
      _logger.error('Failed to fetch RSS feed after retries: $url', e);
      return <NewsArticle>[];
    }
  }

  static List<NewsArticle> _parseRssInBackground(String xmlBody) {
    try {
      try {
        final RssFeed feed = RssFeed.parse(xmlBody);
        final String feedTitle = feed.title ?? '';
        final String feedLink = feed.link ?? '';

        final articles = feed.items
                ?.map((item) {
                  final model = NewsArticleModel.fromRssItem(item);
                  
                  // Fix Source: Use feed title if item source is empty
                  String source = model.source;
                  if (source.isEmpty) {
                    source = feedTitle;
                  }

                  // Fix URL: Check if link is missing or points to feed root
                  String url = model.url;
                  final String? guid = item.guid;
                  
                  // If URL is empty OR equals feed root, try to use GUID if it's a link
                  if ((url.isEmpty || url == feedLink) && guid != null && guid.startsWith('http')) {
                    url = guid;
                  }

                  // Fix Title: Fallback to description/snippet if title is empty
                  String title = model.title;
                  if (title.isEmpty && model.snippet.isNotEmpty) {
                    title = model.snippet;
                  }

                  return model.toDomain().copyWith(
                    source: source,
                    url: url,
                    title: title,
                  );
                })
                .where(
                  (NewsArticle a) => a.title.isNotEmpty && a.url.isNotEmpty,
                )
                .toList() ??
            <NewsArticle>[];
        return articles;
      } catch (_) {
        final AtomFeed feed = AtomFeed.parse(xmlBody);
        final String feedTitle = feed.title ?? '';
        
        final articles = feed.items
                ?.map((item) {
                  final model = NewsArticleModel.fromAtomItem(item);
                  
                  // Fix Source
                  String source = model.source;
                  if (source.isEmpty) {
                    source = feedTitle;
                  }
                  
                  return model.toDomain().copyWith(source: source);
                })
                .where(
                  (NewsArticle a) => a.title.isNotEmpty && a.url.isNotEmpty,
                )
                .toList() ??
            <NewsArticle>[];
        return articles;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error parsing feed in isolate: $e');
      }
      return <NewsArticle>[];
    }
  }
}
