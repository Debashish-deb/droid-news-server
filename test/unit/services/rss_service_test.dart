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
    when(
      mockNetwork.getAdaptiveTimeout(),
    ).thenReturn(const Duration(seconds: 10));
  });

  RssService buildRssService(http.Client client) {
    return RssService(client, mockNetwork, mockLogger);
  }

  String buildRssFeed({
    required String feedTitle,
    required String host,
    required List<int> minutesDesc,
  }) {
    final items = minutesDesc
        .map(
          (m) =>
              '''
    <item>
      <title>$feedTitle article $m</title>
      <link>https://$host/article-$m</link>
      <description>Test description $m</description>
      <pubDate>Mon, 25 Dec 2024 10:${m.toString().padLeft(2, '0')}:00 GMT</pubDate>
    </item>''',
        )
        .join();
    return '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>$feedTitle</title>
    $items
  </channel>
</rss>''';
  }

  group('RssService', () {
    group('Categories', () {
      test(
        'TC-UNIT-040: RssService.categories contains expected categories',
        () {
          expect(RssService.categories, contains('latest'));
        },
      );

      test('TC-UNIT-041: Categories list is not empty', () {
        expect(RssService.categories.length, greaterThan(0));
      });
    });

    group('Fetch News', () {
      test(
        'TC-UNIT-042: fetchNews with empty feeds returns empty list',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response('Not Found', 404);
          });

          final rssService = buildRssService(mockClient);

          final articles = await rssService.fetchNews(
            category: 'nonexistent_category',
            locale: const Locale('en'),
          );

          expect(articles, isEmpty);
        },
      );

      test(
        'TC-UNIT-043: fetchNews handles network errors gracefully',
        () async {
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
        },
      );

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

      test(
        'TC-UNIT-045: fetchNews does not truncate when only one feed remains',
        () async {
          final latestEnUrls = RssService.feeds['latest']!['en']!;
          final selectedUrl = latestEnUrls.first;
          final disabledUrls = latestEnUrls
              .where((url) => url != selectedUrl)
              .toSet();

          final singleFeedXml = buildRssFeed(
            feedTitle: 'Single Source Feed',
            host: 'single.example.com',
            minutesDesc: <int>[59, 58, 57, 56, 55],
          );

          final mockClient = MockClient((request) async {
            if (request.url.toString() == selectedUrl) {
              return http.Response(
                singleFeedXml,
                200,
                headers: {'content-type': 'application/rss+xml; charset=utf-8'},
              );
            }
            return http.Response('Not Found', 404);
          });

          final rssService = buildRssService(mockClient);
          final articles = await rssService.fetchNews(
            category: 'latest',
            locale: const Locale('en'),
            disabledUrls: disabledUrls,
          );

          expect(articles.length, 5);
          expect(
            articles.every((article) => article.source == 'Single Source Feed'),
            isTrue,
          );
        },
      );

      test(
        'TC-UNIT-046: fetchNews keeps source diversity near top results',
        () async {
          final latestEnUrls = RssService.feeds['latest']!['en']!;
          final primaryUrl = latestEnUrls[0];
          final secondaryUrl = latestEnUrls[1];
          final disabledUrls = latestEnUrls
              .where((url) => url != primaryUrl && url != secondaryUrl)
              .toSet();

          final primaryXml = buildRssFeed(
            feedTitle: 'Kaler Kantha',
            host: 'kaler.example.com',
            minutesDesc: <int>[59, 58, 57, 56],
          );
          final secondaryXml = buildRssFeed(
            feedTitle: 'Daily Star',
            host: 'star.example.com',
            minutesDesc: <int>[55, 54, 53],
          );

          final mockClient = MockClient((request) async {
            final url = request.url.toString();
            if (url == primaryUrl) {
              return http.Response(
                primaryXml,
                200,
                headers: {'content-type': 'application/rss+xml; charset=utf-8'},
              );
            }
            if (url == secondaryUrl) {
              return http.Response(
                secondaryXml,
                200,
                headers: {'content-type': 'application/rss+xml; charset=utf-8'},
              );
            }
            return http.Response('Not Found', 404);
          });

          final rssService = buildRssService(mockClient);
          final articles = await rssService.fetchNews(
            category: 'latest',
            locale: const Locale('en'),
            disabledUrls: disabledUrls,
          );

          expect(articles.length, greaterThanOrEqualTo(3));
          final firstThreeSources = articles
              .take(3)
              .map((article) => article.source)
              .toSet();
          expect(firstThreeSources.contains('Daily Star'), isTrue);
        },
      );
    });
  });
}
