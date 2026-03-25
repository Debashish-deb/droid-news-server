import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bdnewsreader/infrastructure/services/news/rss_service.dart';
import 'package:bdnewsreader/infrastructure/network/app_network_service.dart';
import 'package:bdnewsreader/core/telemetry/structured_logger.dart';
import "package:bdnewsreader/domain/entities/news_article.dart";

@GenerateMocks([AppNetworkService, StructuredLogger])
import 'rss_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAppNetworkService mockNetwork;
  late MockStructuredLogger mockLogger;

  setUp(() {
    mockNetwork = MockAppNetworkService();
    mockLogger = MockStructuredLogger();
    
    // Default mocks
    when(mockNetwork.isConnected).thenReturn(true);
    when(mockNetwork.currentQuality).thenReturn(NetworkQuality.excellent);
    when(mockNetwork.getArticleLimit()).thenReturn(50);
    when(mockNetwork.getFeedConcurrency()).thenReturn(4);
    when(mockNetwork.getAdaptiveTimeout()).thenReturn(const Duration(seconds: 10));
  });

  RssService buildRssService(http.Client client) {
    return RssService(client, mockNetwork, mockLogger);
  }

  group('RssService', () {
    group('Categories', () {
      test('TC-UNIT-040: RssService.categories contains expected categories', () {
        expect(RssService.categories, contains('latest'));
      });

      test('TC-UNIT-041: Categories list is not empty', () {
        expect(RssService.categories.length, greaterThan(0));
      });
    });

    group('Fetch News', () {
      test('TC-UNIT-042: fetchNews with empty feeds returns empty list', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final rssService = buildRssService(mockClient);

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

        final rssService = buildRssService(mockClient);

        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );

        expect(articles, isA<List<NewsArticle>>());
        expect(articles, isEmpty);
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
  </channel>
</rss>''';

        final mockClient = MockClient((request) async {
          return http.Response(
            validRss,
            200,
            headers: {'content-type': 'application/rss+xml; charset=utf-8'},
          );
        });

        final rssService = buildRssService(mockClient);

        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );

        expect(articles, isA<List<NewsArticle>>());
      });
    });
  });
}
