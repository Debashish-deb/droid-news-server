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

class _FixedClassifier implements NewsFeedCategoryClassifier {
  @override
  Future<TagDrivenCategorizationResult> classify({
    required String title,
    required String description,
    String? content,
    String language = 'en',
    String? articleId,
    String? feedCategory,
    bool collectAiSignals = true,
    void Function(Map<String, dynamic> insight)? onAiInsight,
  }) async {
    return const TagDrivenCategorizationResult(
      category: 'national',
      confidence: 0.9,
      source: 'test',
      matchedTags: <String>[
        'country:bangladesh',
        'district:dhaka',
        'topic:taxes',
      ],
    );
  }

  @override
  void overrideTaxonomyForTesting(FeedCategoryTaxonomy taxonomy) {}
}

void main() {
  group('NewsRepository tags persistence', () {
    late AppDatabase db;
    late http.Client client;
    late RssService rssService;
    late NewsRepositoryImpl repository;
    late _MockClassifier mockClassifier;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      client = http.Client();
      mockClassifier = _MockClassifier();
      final logger = StructuredLogger();
      final networkService = AppNetworkService();
      rssService = RssService(client, networkService, logger);
      repository = NewsRepositoryImpl(
        db,
        rssService,
        mockClassifier,
        runBootstrap: false,
      );
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

    test('local reclassification backfill is idempotent', () async {
      final fixedRepository = NewsRepositoryImpl(
        db,
        rssService,
        _FixedClassifier(),
        runBootstrap: false,
      );

      await db
          .into(db.articles)
          .insert(
            ArticlesCompanion.insert(
              id: 'article-reclass-1',
              title: 'Dhaka budget coordination meeting',
              description: const Value('Bangladesh ministry issued guidance'),
              url: 'https://example.com/article-reclass-1',
              content: const Value('local governance content'),
              source: 'Example Source',
              language: const Value('en'),
              publishedAt: DateTime(2026, 3, 6),
              category: const Value('entertainment'),
              tags: Value(jsonEncode(<String>['format:breaking', 'topic:tax'])),
            ),
          );

      final firstRun = await fixedRepository.reclassifyRecentCachedArticles(
        limit: 20,
        batchSize: 5,
      );
      final secondRun = await fixedRepository.reclassifyRecentCachedArticles(
        limit: 20,
        batchSize: 5,
      );

      expect(firstRun, 1);
      expect(secondRun, 0);

      final row = await (db.select(
        db.articles,
      )..where((t) => t.id.equals('article-reclass-1'))).getSingle();
      expect(row.category, 'national');
      expect(row.tags, isNot(equals(null)));
      final decoded = List<String>.from(jsonDecode(row.tags!));
      expect(decoded, contains('district:dhaka'));
      expect(decoded.where((tag) => tag.contains('tax')).length, 1);
      expect(decoded.any((tag) => tag.startsWith('format:')), isFalse);
    });
  });
}
