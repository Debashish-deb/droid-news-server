import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webfeed_revised/webfeed_revised.dart';
import '../../../core/telemetry/performance_metrics.dart'
    show PerformanceMetrics;
import '../../../core/utils/retry_helper.dart';
import '../../../core/utils/url_identity.dart';
import '../../../core/utils/article_language_gate.dart';
import '../../network/app_network_service.dart';
import '../../../domain/entities/news_article.dart';
import '../../persistence/models/news_article.dart';

import '../../../core/telemetry/structured_logger.dart';

enum FeedRequestOutcome { successWithData, successNoData, offline, error }

enum _FeedFetchStatus { successWithData, notModified, successNoData, error }

class _FeedFetchResult {
  const _FeedFetchResult({required this.articles, required this.status});

  final List<NewsArticle> articles;
  final _FeedFetchStatus status;

  bool get hasData => articles.isNotEmpty;

  bool get wasSuccessful =>
      status == _FeedFetchStatus.successWithData ||
      status == _FeedFetchStatus.notModified ||
      status == _FeedFetchStatus.successNoData;
}

class RssService {
  RssService(
    this._client,
    this._networkService,
    this._logger, {
    SharedPreferences? prefs,
  }) : _prefs = prefs;
  final http.Client _client;
  final AppNetworkService _networkService;
  final StructuredLogger _logger;
  final SharedPreferences? _prefs;
  static const int _maxArticlesPerFeed = 40;
  static final Map<String, int> _feedFailureCounts = <String, int>{};
  static final Map<String, DateTime> _feedDisabledUntil = <String, DateTime>{};
  static final Map<String, int> _feedAvgLatencyMs = <String, int>{};
  // ETag / Last-Modified conditional-GET support — avoids re-downloading
  // unchanged feeds on every refresh cycle.
  static final Map<String, String> _feedEtags = <String, String>{};
  static final Map<String, String> _feedLastModified = <String, String>{};
  final Map<String, FeedRequestOutcome> _lastRequestOutcomes =
      <String, FeedRequestOutcome>{};
  static const String _rssEtagKeyPrefix = 'rss_feed_etag_';
  static const String _rssLastModifiedKeyPrefix = 'rss_feed_last_modified_';

  static const List<String> categories = <String>[
    'latest',
    'national',
    'international',
    'sports',
    'entertainment',
    'trending',
  ];

  static const Map<String, Map<String, List<String>>>
  feeds = <String, Map<String, List<String>>>{
    'latest': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/feed',
        'https://news.google.com/rss?hl=bn&gl=BD&ceid=BD:bn',
        'https://feeds.bbci.co.uk/bengali/rss.xml',
        'https://www.kalerkantho.com/rss.xml',
        'https://www.jugantor.com/feed/national/rss.xml',
        'https://www.bd-pratidin.com/rss.xml',
      ],
      'en': <String>[
        'https://news.google.com/rss?hl=en-BD&gl=BD&ceid=BD:en',
        'https://www.thedailystar.net/frontpage/rss.xml',
        'https://www.dhakatribune.com/feed/all-news/',
        'https://feeds.bbci.co.uk/news/world/rss.xml',
        'https://www.aljazeera.com/xml/rss/all.xml',
      ],
    },
    'national': <String, List<String>>{
      'bn': <String>[
        'https://www.jugantor.com/feed/national/rss.xml',
        'https://www.bd-pratidin.com/national/rss.xml',
        'https://www.kalerkantho.com/rss.xml',
      ],
      'en': <String>[
        'https://www.thedailystar.net/frontpage/rss.xml',
        'https://www.dhakatribune.com/feed/bangladesh',
        'https://www.bssnews.net/feed',
      ],
    },
    'international': <String, List<String>>{
      'bn': <String>[
        'https://feeds.bbci.co.uk/bengali/world/rss.xml',
        'https://www.jugantor.com/feed/international/rss.xml',
      ],
      'en': <String>[
        'https://theguardian.com/world/rss',
        'https://feeds.bbci.co.uk/news/world/rss.xml',
        'https://www.aljazeera.com/xml/rss/all.xml',
      ],
    },
    'sports': <String, List<String>>{
      'bn': <String>[
        'https://www.jugantor.com/feed/sports/rss.xml',
        'https://feeds.bbci.co.uk/bengali/sport/rss.xml',
      ],
      'en': <String>[
        'https://feeds.bbci.co.uk/sport/rss.xml',
        'https://www.thedailystar.net/sports/rss.xml',
      ],
    },
    'entertainment': <String, List<String>>{
      'bn': <String>[
        'https://www.jugantor.com/feed/entertainment/rss.xml',
        'https://feeds.bbci.co.uk/bengali/entertainment/rss.xml',
      ],
      'en': <String>[
        'https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml',
        'https://www.thedailystar.net/entertainment/rss.xml',
      ],
    },
    'trending': <String, List<String>>{
      'bn': <String>[
        'https://www.prothomalo.com/feed', // Top general as fallback for trending
        'https://www.jugantor.com/feed/national/rss.xml',
        'https://feeds.bbci.co.uk/bengali/rss.xml',
      ],
      'en': <String>[
        'https://news.google.com/rss?hl=en-BD&gl=BD&ceid=BD:en',
        'https://www.thedailystar.net/frontpage/rss.xml',
      ],
    },
  };

  Future<List<NewsArticle>> fetchNews({
    required String category,
    required Locale locale,
    BuildContext? context,
    bool preferRss = false,
    Set<String>? disabledUrls,
  }) async {
    final String lang = locale.languageCode == 'bn' ? 'bn' : 'en';
    List<String> urls = feeds[category]?[lang] ?? const <String>[];
    final requestKey = _requestKey(category: category, language: lang);

    if (disabledUrls != null && disabledUrls.isNotEmpty) {
      urls = urls.where((url) => !disabledUrls.contains(url)).toList();
    }

    if (urls.isEmpty) {
      _lastRequestOutcomes[requestKey] = FeedRequestOutcome.error;
      return <NewsArticle>[];
    }
    if (!_networkService.isConnected) {
      _logger.warn('Skipping RSS fetch: offline');
      _lastRequestOutcomes[requestKey] = FeedRequestOutcome.offline;
      return <NewsArticle>[];
    }

    final List<NewsArticle> all = <NewsArticle>[];
    final gateCounters = <String, int>{};
    var sawSuccessfulFeed = false;

    try {
      // Allow overriding with a set of enabled URLs mapping (can be done here or passed via constructor/dependencies)
      // Since fetchNews is called from providers, ideally providers should pass disabled sources. For now, since
      // RssService doesn't have the source repo directly, we'll pass an optional set of disabled source URLs.
      // Easiest is to add an optional `Set<String>? disabledUrls` to fetchNews.
      final List<String> selectedUrls = _selectUrlsForQuality(urls);
      final List<_FeedFetchResult> results = await _fetchFeeds(
        urls: selectedUrls,
        category: category,
        language: lang,
        context: context,
      );

      sawSuccessfulFeed = results.any((result) => result.wasSuccessful);

      for (final _FeedFetchResult result in results) {
        final list = result.articles;
        for (final article in list) {
          final gate = ArticleLanguageGate.evaluate(
            article: article,
            requestedLanguage: lang,
          );
          gateCounters[gate.reasonCode] =
              (gateCounters[gate.reasonCode] ?? 0) + 1;

          if (!gate.accepted) continue;

          final normalizedLanguage = gate.detectedLanguage == 'unknown'
              ? (lang == 'bn' ? 'bn' : article.language)
              : gate.detectedLanguage;
          all.add(article.copyWith(language: normalizedLanguage));
        }
      }
    } catch (e) {
      _logger.error('Error fetching bulk news', e);
      _lastRequestOutcomes[requestKey] = FeedRequestOutcome.error;
    }

    if (gateCounters.isNotEmpty) {
      _logger.info('RSS language gate', <String, dynamic>{
        'category': category,
        'requested_language': lang,
        'reason_counts': gateCounters,
      });
    }

    final Set<String> seen = <String>{};
    final List<NewsArticle> deduped = all
        .where((NewsArticle a) => seen.add(_canonicalArticleKey(a.url)))
        .toList();

    deduped.sort(
      (NewsArticle a, NewsArticle b) => b.publishedAt.compareTo(a.publishedAt),
    );

    final interleaved = _interleaveArticles(deduped);

    // Keep source-diversified ordering from `_interleaveArticles`.
    // Re-sorting purely by timestamp here collapses the top slice back to a
    // single fast-publishing source, which defeats feed management intent.
    final maxArticles = _networkService.getArticleLimit();
    final articles = interleaved.take(maxArticles).toList(growable: false);
    _lastRequestOutcomes[requestKey] = articles.isNotEmpty
        ? FeedRequestOutcome.successWithData
        : sawSuccessfulFeed
        ? FeedRequestOutcome.successNoData
        : FeedRequestOutcome.error;
    return articles;
  }

  FeedRequestOutcome lastRequestOutcome({
    required String category,
    required String language,
  }) {
    return _lastRequestOutcomes[_requestKey(
          category: category,
          language: language,
        )] ??
        FeedRequestOutcome.error;
  }

  bool wasLastFetchSuccessful({
    required String category,
    required String language,
  }) {
    final outcome = lastRequestOutcome(category: category, language: language);
    return outcome == FeedRequestOutcome.successWithData ||
        outcome == FeedRequestOutcome.successNoData;
  }

  List<String> _selectUrlsForQuality(List<String> urls) {
    final now = DateTime.now();
    final healthyUrls = urls
        .where((url) {
          final disabledUntil = _feedDisabledUntil[url];
          if (disabledUntil == null) return true;
          return now.isAfter(disabledUntil);
        })
        .toList(growable: false);
    final candidates = healthyUrls.isEmpty
        ? List<String>.from(urls)
        : healthyUrls;
    candidates.sort(
      (a, b) => _feedPriorityScore(a).compareTo(_feedPriorityScore(b)),
    );

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

    final selected = candidates.take(maxFeeds).toList(growable: true);

    // Prevent hard lock to a single source after transient failures.
    // When possible, keep one extra probe feed so diversification can recover.
    if (selected.length < 2 && urls.length > 1) {
      final probePool = List<String>.from(
        urls,
      )..sort((a, b) => _feedPriorityScore(a).compareTo(_feedPriorityScore(b)));
      for (final url in probePool) {
        if (selected.contains(url)) continue;
        selected.add(url);
        if (selected.length >= 2) break;
      }
    }

    return selected;
  }

  int _feedPriorityScore(String url) {
    final latency = _feedAvgLatencyMs[url] ?? 4000;
    final failures = _feedFailureCounts[url] ?? 0;
    return latency + (failures * 1500);
  }

  Future<List<_FeedFetchResult>> _fetchFeeds({
    required List<String> urls,
    required String category,
    required String language,
    BuildContext? context,
  }) async {
    final maxConcurrent = _networkService.getFeedConcurrency();
    if (maxConcurrent <= 1) {
      final List<_FeedFetchResult> results = [];
      for (final url in urls) {
        results.add(
          await _fetchSingleFeed(
            url: url,
            category: category,
            language: language,
            context: context,
          ),
        );
      }
      return results;
    }

    final List<_FeedFetchResult> results = [];
    for (int i = 0; i < urls.length; i += maxConcurrent) {
      final batch = urls.sublist(i, math.min(i + maxConcurrent, urls.length));
      final batchResults = await Future.wait(
        batch.map(
          (String url) => _fetchSingleFeed(
            url: url,
            category: category,
            language: language,
            context: context,
          ),
        ),
      );
      results.addAll(batchResults);
    }
    return results;
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
        if (bestArticle == null ||
            candidate.publishedAt.isAfter(bestArticle.publishedAt)) {
          bestArticle = candidate;
          bestSource = source;
        }
      }

      // If we're stuck (e.g. only one source left and we hit the limit), break or force pick?
      // Soft fallback: allow continuity if strict rule would truncate the feed.
      if (bestSource == null) {
        for (final source in bySource.keys) {
          final candidate = bySource[source]!.first;
          if (bestArticle == null ||
              candidate.publishedAt.isAfter(bestArticle.publishedAt)) {
            bestArticle = candidate;
            bestSource = source;
          }
        }
        if (bestSource == null) break;
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

  Future<_FeedFetchResult> _fetchSingleFeed({
    required String url,
    required String category,
    required String language,
    BuildContext? context,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Fetching RSS feed: $url');
      }

      final Duration timeout = _networkService.getAdaptiveTimeout();
      final metricName = 'RssService.fetch($url)';
      PerformanceMetrics().startTimer(metricName);
      final sw = Stopwatch()..start();

      // Build conditional-GET headers to avoid re-downloading unchanged feeds.
      final conditionalHeaders = <String, String>{};
      _hydrateConditionalHeadersFromPrefs(url);
      final cachedEtag = _feedEtags[url];
      final cachedLastMod = _feedLastModified[url];
      if (cachedEtag != null) {
        conditionalHeaders['If-None-Match'] = cachedEtag;
      }
      if (cachedLastMod != null) {
        conditionalHeaders['If-Modified-Since'] = cachedLastMod;
      }

      final http.Response res = await RetryHelper.retry(
        operation: () async {
          final http.Response response = await _client
              .get(
                Uri.parse(url),
                headers: <String, String>{
                  'User-Agent':
                      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                  'Accept':
                      'application/rss+xml, application/xml, text/xml, */*',
                  'Accept-Language': language == 'bn'
                      ? 'bn-BD,bn;q=0.9,en;q=0.6'
                      : 'en-BD,en;q=0.9,bn;q=0.5',
                  'Accept-Encoding': 'gzip, deflate',
                  'Connection': 'keep-alive',
                  'Cache-Control': 'max-age=0',
                  ...conditionalHeaders,
                },
              )
              .timeout(timeout);
          return response;
        },
      );
      sw.stop();
      _networkService.registerRequestLatency(sw.elapsed);

      PerformanceMetrics().stopTimer(
        metricName,
        attributes: {'statusCode': res.statusCode},
      );

      // 304 Not Modified — feed unchanged, return empty so caller uses DB cache.
      if (res.statusCode == 304) {
        _recordFeedSuccess(url, sw.elapsed);
        if (kDebugMode) debugPrint('📡 RSS 304 Not Modified: $url');
        return const _FeedFetchResult(
          articles: <NewsArticle>[],
          status: _FeedFetchStatus.notModified,
        );
      }

      if (res.statusCode != 200) {
        _recordFeedFailure(url, statusCode: res.statusCode);
        _logger.warn('RSS feed returned ${res.statusCode} for $url');
        return const _FeedFetchResult(
          articles: <NewsArticle>[],
          status: _FeedFetchStatus.error,
        );
      }

      // Store ETag / Last-Modified for next conditional-GET.
      final prefs = _prefs;
      final etag = res.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        _feedEtags[url] = etag;
        if (prefs != null) {
          unawaited(prefs.setString(_etagPrefsKey(url), etag));
        }
      } else {
        _feedEtags.remove(url);
        if (prefs != null) {
          unawaited(prefs.remove(_etagPrefsKey(url)));
        }
      }
      final lastMod = res.headers['last-modified'];
      if (lastMod != null && lastMod.isNotEmpty) {
        _feedLastModified[url] = lastMod;
        if (prefs != null) {
          unawaited(prefs.setString(_lastModifiedPrefsKey(url), lastMod));
        }
      } else {
        _feedLastModified.remove(url);
        if (prefs != null) {
          unawaited(prefs.remove(_lastModifiedPrefsKey(url)));
        }
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
        return const _FeedFetchResult(
          articles: <NewsArticle>[],
          status: _FeedFetchStatus.error,
        );
      }

      final parsed = await compute(_parseRssInBackground, body);
      _recordFeedSuccess(url, sw.elapsed);
      final trimmed = parsed.length <= _maxArticlesPerFeed
          ? parsed
          : parsed.take(_maxArticlesPerFeed).toList(growable: false);
      return _FeedFetchResult(
        articles: trimmed,
        status: trimmed.isEmpty
            ? _FeedFetchStatus.successNoData
            : _FeedFetchStatus.successWithData,
      );
    } on TimeoutException catch (e) {
      _recordFeedFailure(url, timeout: true);
      _logger.warning('RSS feed timeout for $url', e);
      return const _FeedFetchResult(
        articles: <NewsArticle>[],
        status: _FeedFetchStatus.error,
      );
    } catch (e) {
      _recordFeedFailure(url);
      _logger.error('Failed to fetch RSS feed after retries: $url', e);
      return const _FeedFetchResult(
        articles: <NewsArticle>[],
        status: _FeedFetchStatus.error,
      );
    }
  }

  String _requestKey({required String category, required String language}) =>
      '${category.toLowerCase()}|${language.toLowerCase()}';

  String _etagPrefsKey(String url) =>
      '$_rssEtagKeyPrefix${UrlIdentity.idFromUrl(url)}';

  String _lastModifiedPrefsKey(String url) =>
      '$_rssLastModifiedKeyPrefix${UrlIdentity.idFromUrl(url)}';

  void _hydrateConditionalHeadersFromPrefs(String url) {
    final prefs = _prefs;
    if (prefs == null) return;

    if (!_feedEtags.containsKey(url)) {
      final persistedEtag = prefs.getString(_etagPrefsKey(url));
      if (persistedEtag != null && persistedEtag.isNotEmpty) {
        _feedEtags[url] = persistedEtag;
      }
    }

    if (!_feedLastModified.containsKey(url)) {
      final persistedLastModified = prefs.getString(_lastModifiedPrefsKey(url));
      if (persistedLastModified != null && persistedLastModified.isNotEmpty) {
        _feedLastModified[url] = persistedLastModified;
      }
    }
  }

  void _recordFeedSuccess(String url, Duration elapsed) {
    _feedFailureCounts.remove(url);
    _feedDisabledUntil.remove(url);
    final sample = elapsed.inMilliseconds.clamp(1, 120000);
    final prev = _feedAvgLatencyMs[url];
    if (prev == null) {
      _feedAvgLatencyMs[url] = sample;
      return;
    }
    _feedAvgLatencyMs[url] = ((prev * 3) + sample) ~/ 4;
  }

  void _recordFeedFailure(String url, {int? statusCode, bool timeout = false}) {
    final failureCount = (_feedFailureCounts[url] ?? 0) + 1;
    _feedFailureCounts[url] = failureCount;

    Duration base;
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      base = (statusCode == 404 || statusCode == 410)
          ? const Duration(minutes: 20)
          : const Duration(minutes: 10);
    } else if (timeout) {
      base = const Duration(minutes: 4);
    } else {
      base = const Duration(minutes: 2);
    }

    final multiplier = failureCount > 6 ? 6 : failureCount;
    _feedDisabledUntil[url] = DateTime.now().add(base * multiplier);
  }

  static String _canonicalArticleKey(String rawUrl) {
    return UrlIdentity.canonicalize(rawUrl);
  }

  static List<NewsArticle> _parseRssInBackground(String xmlBody) {
    try {
      try {
        final RssFeed feed = RssFeed.parse(xmlBody);
        final String feedTitle = feed.title ?? '';
        final String feedLink = feed.link ?? '';

        final articles =
            feed.items
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
                  if ((url.isEmpty || url == feedLink) &&
                      guid != null &&
                      guid.startsWith('http')) {
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

        final articles =
            feed.items
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
