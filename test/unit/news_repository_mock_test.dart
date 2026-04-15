import 'package:bdnewsreader/platform/persistence/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:bdnewsreader/infrastructure/repositories/news_repository_impl.dart';
import 'package:bdnewsreader/infrastructure/persistence/vault/vault_database.dart'
    as vault;
import 'package:bdnewsreader/infrastructure/services/news/rss_service.dart';
import 'package:bdnewsreader/infrastructure/services/news/news_api_service.dart';
import 'package:bdnewsreader/domain/services/ai_service.dart';
import 'package:bdnewsreader/infrastructure/services/ml/news_feed_category_classifier.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:logger/logger.dart';
import 'dart:ui';

@GenerateNiceMocks([
  MockSpec<SharedPreferences>(),
  MockSpec<vault.VaultDatabase>(),
  MockSpec<RssService>(),
  MockSpec<NewsApiService>(),
  MockSpec<AIService>(),
  MockSpec<NewsFeedCategoryClassifier>(),
  MockSpec<Logger>(),
])
import 'news_repository_mock_test.mocks.dart';

void main() {
  group('NewsRepositoryImpl Mock Data', () {
    late NewsRepositoryImpl repository;
    late AppDatabase db;
    late MockRssService mockRss;
    late MockNewsFeedCategoryClassifier mockClassifier;

    setUp(() async {
      mockRss = MockRssService();
      mockClassifier = MockNewsFeedCategoryClassifier();

      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = NewsRepositoryImpl(
        db,
        mockRss,
        mockClassifier,
        runBootstrap: false,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('syncNews correctly uses RSS service', () async {
      final articles = [
        NewsArticle(
          title: 'Test',
          url: 'test.com',
          source: 'Source',
          publishedAt: DateTime.now(),
        ),
      ];

      // Stub specifically for the test category 'entertainment'
      when(
        mockRss.fetchNews(
          category: 'entertainment',
          locale: anyNamed('locale'),
        ),
      ).thenAnswer((_) async => articles);

      // Default return empty for other categories
      when(
        mockRss.fetchNews(
          category: argThat(isNot('entertainment'), named: 'category'),
          locale: anyNamed('locale'),
        ),
      ).thenAnswer((_) async => []);

      when(
        mockRss.wasLastFetchSuccessful(
          category: 'entertainment',
          language: 'en',
        ),
      ).thenReturn(true);

      when(
        mockClassifier.classify(
          title: anyNamed('title'),
          description: anyNamed('description'),
          content: anyNamed('content'),
          language: anyNamed('language'),
          articleId: anyNamed('articleId'),
          feedCategory: anyNamed('feedCategory'),
          collectAiSignals: anyNamed('collectAiSignals'),
          onAiInsight: anyNamed('onAiInsight'),
        ),
      ).thenAnswer(
        (_) async => const TagDrivenCategorizationResult(
          category: 'entertainment',
          confidence: 0.9,
          source: 'test',
        ),
      );

      final result = await repository.syncNews(
        locale: const Locale('en'),
        category: 'entertainment',
      );

      print('syncNews result: $result');
      expect(result.isRight(), true);
      // It returns the count of inserted articles.
      // Since it's a new article, it should be 1.
      expect(result.getOrElse(0), 1);
    });
  });
}
