import 'dart:convert';

import 'package:bdnewsreader/infrastructure/repositories/news_repository_impl.dart';
import 'package:bdnewsreader/infrastructure/services/news/rss_service.dart';
import 'package:bdnewsreader/core/telemetry/structured_logger.dart';
import 'package:bdnewsreader/infrastructure/network/app_network_service.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/platform/persistence/app_database.dart';
import 'package:bdnewsreader/infrastructure/services/ml/news_feed_category_classifier.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

class _MockClassifier extends Mock implements NewsFeedCategoryClassifier {}

void main() {
  group('NewsRepository tags persistence', () {
    late AppDatabase db;
    late http.Client client;
    late NewsRepositoryImpl repository;
    late _MockClassifier mockClassifier;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      client = http.Client();
      mockClassifier = _MockClassifier();
      final logger = StructuredLogger();
      final networkService = AppNetworkService();
      final rssService = RssService(client, networkService, logger);
      repository = NewsRepositoryImpl(db, rssService, mockClassifier);
    });

    tearDown(() async {
      client.close();
      await db.close();
    });

    test('decodes stored tags JSON into NewsArticle.tags', () async {
      final persistedTags = <String>[
        'district:dhaka',
        'topic:politics',
        'format:breaking',
      ];

      await db
          .into(db.articles)
          .insert(
            ArticlesCompanion.insert(
              id: 'article-1',
              title: 'Policy update in Dhaka',
              description: const Value('Bangladesh governance update'),
              url: 'https://example.com/article-1',
              content: const Value('full content'),
              source: 'Example Source',
              language: const Value('en'),
              publishedAt: DateTime(2026, 3, 6),
              category: const Value('national'),
              tags: Value(jsonEncode(persistedTags)),
            ),
          );

      final result = await repository.getNewsFeed(
        page: 1,
        limit: 10,
        category: 'national',
        language: 'en',
      );

      expect(result.isRight(), isTrue);
      final articles = result.getOrElse(<NewsArticle>[]);
      expect(articles, hasLength(1));
      expect(articles.first.tags, equals(persistedTags));
    });

    test('filters weak sports rows from strict sports feed', () async {
      await db
          .into(db.articles)
          .insert(
            ArticlesCompanion.insert(
              id: 'article-sports-weak',
              title: 'Dhaka policy meeting held today',
              description: const Value('General governance and budget talk'),
              url: 'https://example.com/article-sports-weak',
              content: const Value('general content'),
              source: 'Example Source',
              language: const Value('en'),
              publishedAt: DateTime(2026, 3, 6),
              category: const Value('sports'),
            ),
          );

      final result = await repository.getNewsFeed(
        page: 1,
        limit: 20,
        category: 'sports',
        language: 'en',
      );

      expect(result.isRight(), isTrue);
      final articles = result.getOrElse(<NewsArticle>[]);
      expect(articles, isEmpty);
    });

    test('keeps strong sports rows in strict sports feed', () async {
      await db
          .into(db.articles)
          .insert(
            ArticlesCompanion.insert(
              id: 'article-sports-strong',
              title: 'Bangladesh win cricket thriller',
              description: const Value('Cricket world cup clash in Dhaka'),
              url: 'https://example.com/article-sports-strong',
              content: const Value('sports content'),
              source: 'Example Source',
              language: const Value('en'),
              publishedAt: DateTime(2026, 3, 6),
              category: const Value('sports'),
              tags: Value(jsonEncode(<String>['sports:cricket'])),
            ),
          );

      final result = await repository.getNewsFeed(
        page: 1,
        limit: 20,
        category: 'sports',
        language: 'en',
      );

      expect(result.isRight(), isTrue);
      final articles = result.getOrElse(<NewsArticle>[]);
      expect(articles, hasLength(1));
      expect(articles.first.url, 'https://example.com/article-sports-strong');
    });
  });
}
