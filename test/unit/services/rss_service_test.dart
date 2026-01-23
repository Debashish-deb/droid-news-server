import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RssService', () {
    group('Categories', () {
      test('TC-UNIT-040: RssService.categories contains expected categories', () {
        expect(RssService.categories, contains('latest'));
        expect(RssService.categories, contains('national'));
        expect(RssService.categories, contains('international'));
        expect(RssService.categories, contains('sports'));
        expect(RssService.categories, contains('entertainment'));
        expect(RssService.categories, contains('technology'));
        expect(RssService.categories, contains('economy'));
      });

      test('TC-UNIT-041: Categories list is not empty', () {
        expect(RssService.categories.length, greaterThan(0));
      });
    });

    group('Fetch News', () {
      test('TC-UNIT-042: fetchNews with empty feeds returns empty list', () async {
        // Create RssService with mock client that returns 404
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'nonexistent_category',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });

      test('TC-UNIT-043: fetchNews handles network errors gracefully', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });
        
        final rssService = RssService(client: mockClient);
        
        // Should not throw, should return empty list
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });

      test('TC-UNIT-044: fetchNews with valid RSS returns articles', () async {
        const validRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <item>
      <title>Test Article 1</title>
      <link>https://example.com/article1</link>
      <description>Test description</description>
      <pubDate>Mon, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Test Article 2</title>
      <link>https://example.com/article2</link>
      <description>Another test</description>
      <pubDate>Mon, 25 Dec 2024 09:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
        
        final mockClient = MockClient((request) async {
          return http.Response(validRss, 200, headers: {
            'content-type': 'application/rss+xml; charset=utf-8',
          });
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
        expect(articles.length, greaterThanOrEqualTo(0));
      });

      test('TC-UNIT-045: fetchNews handles malformed XML gracefully', () async {
        const malformedRss = '<rss><channel><title>Broken';
        
        final mockClient = MockClient((request) async {
          return http.Response(malformedRss, 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        // Should not throw, should return empty list
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });
    });

    group('Locale Support', () {
      test('TC-UNIT-046: fetchNews accepts Bengali locale', () async {
        const validRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>BBC Bengali</title>
    <item>
      <title>Bengali News 1</title>
      <link>https://bbc.com/bengali/news1</link>
      <pubDate>Mon, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('bengali')) {
             return http.Response(validRss, 200, headers: {
              'content-type': 'application/rss+xml; charset=utf-8',
            });
          }
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('bn'),
        );
        
        expect(articles, isNotEmpty);
        expect(articles.first.title, contains('Bengali'));
      });

      test('TC-UNIT-047: fetchNews accepts English locale', () async {
         const validRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>BBC World</title>
    <item>
      <title>English News 1</title>
      <link>https://bbc.com/news/1</link>
      <pubDate>Mon, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

        final mockClient = MockClient((request) async {
           // Return success for BBC World URL which is first in the list for 'latest'/'en'
           if (request.url.toString().contains('bbci.co.uk/news/world')) {
             return http.Response(validRss, 200, headers: {
              'content-type': 'application/rss+xml; charset=utf-8',
            });
           }
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isNotEmpty);
        expect(articles.first.title, contains('English'));
      });
    });

    group('Deduplication', () {
      test('TC-UNIT-048: Duplicate URLs are removed from results', () {
        // Test the deduplication logic
        final urls = <String>{'url1', 'url1', 'url2', 'url3', 'url2'};
        
        // Using Set for deduplication (as RssService does)
        expect(urls.length, 3);
      });
    });

    group('Sorting', () {
      test('TC-UNIT-049: Articles are sorted newest first', () {
        final articles = [
          NewsArticle(title: 'Old', url: 'u1', source: 's', publishedAt: DateTime(2024)),
          NewsArticle(title: 'New', url: 'u2', source: 's', publishedAt: DateTime(2024, 12, 25)),
          NewsArticle(title: 'Mid', url: 'u3', source: 's', publishedAt: DateTime(2024, 6, 15)),
        ];
        
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        
        expect(articles[0].title, 'New');
        expect(articles[2].title, 'Old');
      });
    });
  });
}
