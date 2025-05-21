import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as https;
import 'package:webfeed_revised/webfeed_revised.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/news_article.dart';

class RssService {
  RssService._();

  static const _cacheDuration = Duration(minutes: 30);
  static const _cacheKeyPrefix = 'newsapi_cache';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize once at app startup
  static Future<void> initializeNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  /// Our four supported categories
  static const List<String> categories = [
    'latest',
    'national',
    'international',
    'lifestyle & education',
  ];

  /// A small fallback of RSS feeds, keyed by category.
  static const Map<String, List<Map<String, String>>> _rssFallback = {
    'latest': [
      {'name': 'প্রথম আলো', 'url': 'https://www.prothomalo.com/feed'},
      {'name': 'বিডিনিউজ২৪ ইংরেজি', 'url': 'https://bdnews24.com/en/rss/en/latest/rss.xml'},
      {'name': 'সমকাল', 'url': 'https://samakal.com/feed'},
      {'name': 'বাংলাদেশ প্রতিদিন', 'url': 'https://www.bd-pratidin.com/rss.xml'},
      {'name': 'মানবজমিন', 'url': 'https://mzamin.com/rss.php'},
      {'name': 'আমাদের সময়', 'url': 'https://www.amadershomoy.com/rss.xml'},
      {'name': 'ইনকিলাব', 'url': 'https://www.dailyinqilab.com/rss.xml'},
      {'name': 'জাগো নিউজ ২৪', 'url': 'https://www.jagonews24.com/rss/rss.xml'},
      {'name': 'বাংলানিউজ২৪', 'url': 'https://www.banglanews24.com/rss/rss.xml'},
      {'name': 'ঢাকা পোস্ট', 'url': 'https://www.dhakapost.com/feed'},
      {'name': 'ইত্তেফাক', 'url': 'https://www.ittefaq.com.bd/feed'},
      {'name': 'কালের কণ্ঠ', 'url': 'https://www.kalerkantho.com/rss.xml'},
      {'name': 'বাংলাদেশ প্রতিদিন-জাতীয়', 'url': 'https://www.bd-pratidin.com/national/rss'},
      {'name': 'নয়া দিগন্ত-রাজনীতি', 'url': 'https://www.dailynayadiganta.com/politics/rss'},
      {'name': 'BBC World', 'url': 'https://feeds.bbci.co.uk/news/world/rss.xml'},
    ],
    'national': [
      {'name': 'বাংলাদেশ প্রতিদিন-জাতীয়', 'url': 'https://www.bd-pratidin.com/national/rss'},
      {'name': 'Cricbuzz BD', 'url': 'https://www.cricbuzz.com/rss/BD.xml'},
      {'name': 'ক্রিকেটবাংলা', 'url': 'https://cricketbangla.com/feed/'},
      {'name': 'বিডিনিউজ২৪-ক্রীড়া', 'url': 'https://bangla.bdnews24.com/category/sport/feed/'},
      {'name': 'বিবিসি-বাংলা', 'url': 'https://feeds.bbci.co.uk/bengali/bangladesh/rss.xml'},
      {'name': 'প্রথম আলো', 'url': 'https://www.prothomalo.com/feed'},
      {'name': 'ESPN CricInfo', 'url': 'https://www.espncricinfo.com/rss/content/story/feeds/0.xml'},
    ],
    'international': [
      {'name': 'BBC World', 'url': 'https://feeds.bbci.co.uk/news/world/rss.xml'},
      {'name': 'DW News', 'url': 'https://rss.dw.com/rdf/rss-en-all'},
      {'name': 'বিবিসি-বাংলা বিশ্ব (World)', 'url': 'https://feeds.bbci.co.uk/bengali/world/rss.xml'},
    ],
    'lifestyle': [
      {'name': 'EdTech Review', 'url': 'https://edtechreview.in/feed'},
      {'name': 'শিক্ষা অধিদপ্তর', 'url': 'https://www.dshe.gov.bd/bn/feed'},
      {'name': 'ক্যাম্পাস টাইমস', 'url': 'https://www.campustimesbd.com/feed/'},
      {'name': 'বিবিসি-বাংলা বিনোদন (Entertainment)', 'url': 'https://feeds.bbci.co.uk/bengali/entertainment/rss.xml'},
    ],
  };

  /// Static helper to expose fallback sources per category
  static List<Map<String, String>> rssFallbackForCategory(String category) =>
      _rssFallback[category] ?? [];

  /// Entry point: fetch for a given category & locale
  /// If [preferRss] is true, skips NewsAPI and loads RSS only.
  static Future<List<NewsArticle>> fetchNews({
    required String category,
    required Locale locale,
    BuildContext? context,
    bool preferRss = false,
  }) async {
    assert(categories.contains(category), 'Unsupported category: $category');

    final rssSources = _rssFallback[category]!;
    if (preferRss) {
      return _fetchFromRss(rssSources, context: context);
    }

    final apiResults = await _fetchFromNewsApi(
      category: category,
      locale: locale,
      context: context,
    );
    if (apiResults.isNotEmpty) return apiResults;

    // Fallback to RSS if NewsAPI fails/returns empty
    return _fetchFromRss(rssSources, context: context);
  }

  /// NewsAPI with caching
  static Future<List<NewsArticle>> _fetchFromNewsApi({
    required String category,
    required Locale locale,
    BuildContext? context,
  }) async {
    final apiKey = dotenv.env['NEWS_API_KEY'] ?? '';
    if (apiKey.isEmpty) throw StateError('NEWS_API_KEY not set in .env');
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final lang = locale.languageCode;
    final cacheKey = '$_cacheKeyPrefix:$category:$lang';
    final cacheTimeKey = '$cacheKey:time';

    final raw = prefs.getString(cacheKey);
    final rawTime = prefs.getString(cacheTimeKey);
    if (raw != null && rawTime != null) {
      final saved = DateTime.tryParse(rawTime);
      if (saved != null && now.difference(saved) < _cacheDuration) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((m) => NewsArticle.fromMap(m as Map<String, dynamic>))
            .toList();
      }
    }

    final isTopHeadlines = category == 'latest' || category == 'sports';
    final endpoint = isTopHeadlines ? 'top-headlines' : 'everything';
    final params = <String, String>{
      'apiKey': apiKey,
      'language': lang,
      if (isTopHeadlines && category == 'sports') 'category': 'sports',
      if (isTopHeadlines && category == 'latest') 'country': 'bd',
      if (!isTopHeadlines && category == 'international') 'q': 'international OR world',
      if (!isTopHeadlines && category == 'education') 'q': 'education OR শিক্ষা',
      'pageSize': '30',
    };

    final uri = Uri.https('newsapi.org', '/v2/$endpoint', params);

    try {
      final res = await https.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final rawArticles = (body['articles'] as List<dynamic>?) ?? [];
        final articles = rawArticles
            .map((j) => NewsArticle.fromMap(j as Map<String, dynamic>))
            .where((a) => a.title.isNotEmpty)
            .toList();

        await prefs.setString(cacheKey, jsonEncode(articles.map((a) => a.toMap()).toList()));
        await prefs.setString(cacheTimeKey, now.toIso8601String());

        if (context != null) {
          for (final a in articles) {
            if (a.imageUrl?.isNotEmpty == true) {
              precacheImage(NetworkImage(a.imageUrl!), context);
            }
          }
        }
        return articles;
      }
    } catch (_) {
      // fail silently to fallback
    }
    return [];
  }

  /// Pure RSS fetch + dedupe
  static Future<List<NewsArticle>> _fetchFromRss(
    List<Map<String, String>> sources, {
    BuildContext? context,
  }) async {
    final client = https.Client();
    final all = <NewsArticle>[];
    try {
      final results = await Future.wait(sources.map((s) {
        return _parseRss(client, s['url']!, s['name'], context);
      }));
      for (var l in results) all.addAll(l);
    } finally {
      client.close();
    }
    final seen = <String>{};
    return all.where((a) => seen.add(a.url)).toList();
  }

  static Future<List<NewsArticle>> _parseRss(
    https.Client client,
    String url,
    String? sourceName,
    BuildContext? context, {
    int retries = 2,
  }) async {
    try {
      final res = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 && retries > 0) {
        await Future.delayed(const Duration(seconds: 2));
        return _parseRss(client, url, sourceName, context, retries: retries - 1);
      }
      if (res.statusCode != 200) return [];

      final ct = res.headers['content-type'];
      final charset = ct?.split('charset=').last ?? 'utf-8';
      final body = Encoding.getByName(charset)!.decode(res.bodyBytes);

      final feed = RssFeed.parse(body);
      final items = feed.items
              ?.map(NewsArticle.fromRssItem)
              .where((a) => a.title.isNotEmpty)
              .toList() ?? [];

      if (context != null) {
        for (final a in items) {
          if (a.imageUrl?.isNotEmpty == true) {
            precacheImage(NetworkImage(a.imageUrl!), context);
          }
        }
      }
      if (sourceName != null) {
        for (final a in items) {
          a.sourceOverride = sourceName;
        }
      }
      return items;
    } catch (_) {
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 2));
        return _parseRss(client, url, sourceName, context, retries: retries - 1);
      }
      return [];
    }
  }

  /// Desktop notifications for new RSS‐only stories
  static Future<void> pollFeedsAndNotify(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList('seenArticles') ?? [];
    final sources = _rssFallback['latest']!;
    final fresh = await _fetchFromRss(sources);
    for (final a in fresh) {
      if (!seen.contains(a.url)) {
        await _showNotification(a.title);
        seen.add(a.url);
      }
    }
    await prefs.setStringList('seenArticles', seen);
  }

  static Future<void> _showNotification(String title) async {
    const android = AndroidNotificationDetails(
      'rss_channel', 'RSS Updates',
      channelDescription: 'New fallback RSS story',
      importance: Importance.max, priority: Priority.high,
    );
    const pd = NotificationDetails(android: android);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '📰 নতুন সংবাদ',
      title,
      pd,
    );
  }
}
