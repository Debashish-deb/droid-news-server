// path: lib/data/services/rss_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed_revised/webfeed_revised.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/news_article.dart';

class RssService {
  static const Map<String, Map<String, List<String>>> _feeds = {
   'bn': {
      'latest': [
        'https://www.prothomalo.com/feed',
        'https://www.kalerkantho.com/rss.xml',
        'https://bangla.bdnews24.com/rss/bangla.xml',
        'https://www.jugantor.com/rss.xml',
        'https://www.ittefaq.com.bd/rss.xml',
        // Indian Bangla additions:
        'https://www.anandabazar.com/rss/abp-bangla-homepage.rss',
        'https://www.eisamay.com/rssfeed',
        'https://bangla.hindustantimes.com/rss/homepage',
        'https://roar.media/bangla/feed',
      ],
      'national': [
        'https://www.ittefaq.com.bd/rss.xml',
        'https://www.jugantor.com/rss.xml',
        'https://mzamin.com/rss.xml',
        'https://www.dailynayadiganta.com/rss.xml',
        'https://www.samakal.com/rss.xml',
        'https://www.kalerkantho.com/rss.xml',
        'https://www.bhorerkagoj.com/feed',
      ],
      'business': [
        'https://bangla.bdnews24.com/economy/rss.xml',
        'https://www.dhakatimes24.com/business/rss.xml',
        'https://www.arthosuchak.com/feed',
        'https://bonikbarta.net/rss.xml',
      ],
      'sports': [
        'https://www.prothomalo.com/sports/feed​',
        'https://bangla.bdnews24.com/sport/rss.xml​',
        'https://www.jugantor.com/sports/rss.xml​',
        'https://www.banglatribune.com/sports/rss.xml​',
        'https://www.jagonews24.com/sports/rss.xml​',
        'https://www.banglanews24.com/rss/sports.rss​',
        'https://www.kalerkantho.com/rss/sports.xml​',
        'https://bengali.abplive.com/sports/feed​',
        'https://bengali.abplive.com/sports/ipl/feed​',
        'https://thewall.in/rssfeed?cat=sports​',
        'https://thewall.in/rssfeed?cat=sports_cricket​',
        'https://thewall.in/rssfeed?cat=sports_football',
      ],
      'technology': [
        'https://bangla.bdnews24.com/tech/rss.xml',
        'https://www.jugantor.com/technology/rss.xml',
        'https://techshohor.com/feed',
        'https://trickbd.com/feed',
        'https://www.priyo.com/tech/rss.xml',
      ],
      'entertainment': [
        'https://bangla.bdnews24.com/entertainment/rss.xml',
        'https://www.prothomalo.com/entertainment/feed',
        'https://www.jugantor.com/entertainment/rss.xml',
        'https://www.banglatribune.com/feed',
        'https://www.bd24live.com/feed​',
        'https://www.risingbd.com/rss/rss.xml​',
        'https://www.banglanews24.com/rss/rss.xml',
        'http://www.kalerkantho.com/rss.xml​',
        'https://www.thedailystar.net/frontpage/rss.xml​',
        'https://bd-journal.com/feed/latest-rss.xml​',
        'https://www.amarbanglabd.com/rss​',
        'https://bengali.abplive.com/home/feed',
        'https://bengali.abplive.com/entertainment/feed',
        'https://bengali.abplive.com/sports/feed​', 'https://zeenews.india.com/bengali/rssfeed.html',
        'https://www.indiatoday.in/rss​',
      ],
      'lifestyle': [
        'https://www.priyo.com/lifestyle/rss.xml',
        'https://www.sahos24.com/rss.xml',
      ],
      'blog': [
        'https://roar.media/bangla/feed',
        'https://www.priyo.com/blog/rss.xml',
      ],
    },
    'en': {
      'breakingNews': [
        'https://rss.cnn.com/rss/edition.rss',
        'https://feeds.bbci.co.uk/news/rss.xml',
        'https://www.thedailystar.net/frontpage/rss.xml',
        'https://www.dhakatribune.com/feed',
      ],
      'national': [
        'https://www.dhakatribune.com/feed',
        'https://www.thedailystar.net/frontpage/rss.xml',
      ],
      'business': [
        'https://feeds.a.dj.com/rss/RSSMarketsMain.xml',
        'https://www.forbes.com/business/feed/',
        'https://www.ft.com/?format=rss',
        'https://www.businesstoday.in/rssfeedstopstories.cms',
      ],
      'sports': [
        'https://www.espn.com/espn/rss/news',
        'https://www.skysports.com/rss/12040',
        'https://www.sportingnews.com/us/rss',
      ],
      'technology': [
        'https://www.techradar.com/rss',
        'https://feeds.arstechnica.com/arstechnica/index',
        'https://thenextweb.com/feed',
      ],
      'entertainment': [
        'https://www.billboard.com/feed/',
        'https://variety.com/feed/',
        'https://www.hollywoodreporter.com/t/feed/',
      ],
      'lifestyle': [
        'https://www.lifehack.org/feed',
        'https://www.mindbodygreen.com/rss',
        'https://www.wellandgood.com/feed/',
      ],
      'blog': [
        'https://medium.com/feed/tag/technology',
        'https://daringfireball.net/feeds/main',
      ],
    },
  };

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  static Map<String, List<String>>? getSafeFeeds(Locale locale) {
    final lang = locale.languageCode.split('-').first;
    return _feeds[lang];
  }

  static Future<List<NewsArticle>> fetchRssFeeds(List<String> urls) async {
    final client = http.Client();
    try {
      final responses = await Future.wait(
        urls.map((url) => _fetch(client, url)),
        eagerError: false,
      );
      final all = responses.expand((list) => list);
      final seen = <String>{};
      return all.where((a) => seen.add(a.url)).toList();
    } finally {
      client.close();
    }
  }

  static Future<List<NewsArticle>> _fetch(http.Client client, String url) async {
    try {
      final response = await client
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final encoding = _extractEncoding(response.headers['content-type']);
      final body = encoding.decode(response.bodyBytes);
      final feed = RssFeed.parse(body);
      return feed.items
              ?.map((item) => NewsArticle.fromRssItem(item))
              .where((a) => a.title.isNotEmpty)
              .toList() ??
          [];
    } catch (_) {
      return [];
    }
  }

  static Encoding _extractEncoding(String? contentType) {
    final charset = contentType?.split('charset=').last ?? 'utf-8';
    return Encoding.getByName(charset) ?? utf8;
  }

  /// 🔥 Auto-poll feeds and send notifications for new unseen articles
  static Future<void> pollFeedsAndNotify(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUrls = prefs.getStringList('seenArticles') ?? [];

    final feeds = getSafeFeeds(locale);
    if (feeds == null) return;

    final breakingNewsFeeds = feeds['breakingNews'] ?? [];
    final newArticles = await fetchRssFeeds(breakingNewsFeeds);

    for (final article in newArticles) {
      if (!storedUrls.contains(article.url)) {
        await _showNotification(article.title);
        storedUrls.add(article.url);
      }
    }

    await prefs.setStringList('seenArticles', storedUrls);
  }

  static Future<void> _showNotification(String title) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rss_channel_id',
      'RSS Updates',
      channelDescription: 'Notifications for new RSS news articles',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '📰 New Article',
      title,
      platformDetails,
    );
  }
}
