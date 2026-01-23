import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('News API Integration', () {
    group('RssService Integration', () {
      test('TC-INT-001: RssService handles successful response', () async {
        const rssXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test News</title>
    <item>
      <title>Breaking News</title>
      <link>https://example.com/news/1</link>
      <pubDate>Wed, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
        
        final mockClient = MockClient((request) async {
          return http.Response(rssXml, 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });

      test('TC-INT-002: RssService handles 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });

      test('TC-INT-003: RssService handles network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });

      test('TC-INT-004: RssService handles malformed XML', () async {
        final mockClient = MockClient((request) async {
          return http.Response('<broken xml', 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });
    });

    group('Category Support', () {
      test('TC-INT-005: All categories are supported', () {
        const categories = RssService.categories;
        
        expect(categories, contains('latest'));
        expect(categories, contains('national'));
        expect(categories, contains('sports'));
        expect(categories, contains('entertainment'));
        expect(categories, contains('international'));
      });
    });

    group('Locale Support', () {
      test('TC-INT-006: Bengali locale is supported', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        // Should not throw
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('bn'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });

      test('TC-INT-007: English locale is supported', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });
    });

    group('Article Processing', () {
      test('TC-INT-008: Articles are deduplicated by URL', () async {
        const rssXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test</title>
    <item>
      <title>Article 1</title>
      <link>https://example.com/same-url</link>
      <pubDate>Wed, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Article 2</title>
      <link>https://example.com/same-url</link>
      <pubDate>Wed, 25 Dec 2024 09:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
        
        final mockClient = MockClient((request) async {
          return http.Response(rssXml, 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        // Should be deduplicated to 1 article
        expect(articles.length, lessThanOrEqualTo(1));
      });
    });
  });
}
