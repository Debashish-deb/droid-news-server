import 'package:bdnewsreader/platform/persistence/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:bdnewsreader/infrastructure/repositories/news_repository_impl.dart';
import 'package:bdnewsreader/infrastructure/persistence/vault/vault_database.dart';
import 'package:bdnewsreader/infrastructure/services/news/rss_service.dart';
import 'package:bdnewsreader/infrastructure/services/news/news_api_service.dart';
import 'package:bdnewsreader/domain/services/ai_service.dart';
import 'package:bdnewsreader/infrastructure/services/ml/news_feed_category_classifier.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/infrastructure/repositories/news/news_repository_sync_helper.dart';
import 'news_sync_count_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SharedPreferences>(),
  MockSpec<VaultDatabase>(),
  MockSpec<RssService>(),
  MockSpec<NewsApiService>(),
  MockSpec<AIService>(),
  MockSpec<NewsFeedCategoryClassifier>(),
])
void main() {
  group('NewsRepositoryImpl New Article Counting', () {
    late NewsRepositoryImpl repository;
    late AppDatabase db;
    late MockSharedPreferences mockPrefs;
    late MockRssService mockRss;
    late MockNewsFeedCategoryClassifier mockClassifier;

    setUp(() async {
      mockPrefs = MockSharedPreferences();
      mockRss = MockRssService();
      mockClassifier = MockNewsFeedCategoryClassifier();

      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = NewsRepositoryImpl(
        db,
        mockRss,
        mockClassifier,
        runBootstrap: false,
      );

      when(mockPrefs.getString(any)).thenReturn('en');
    });

    tearDown(() async {
      await db.close();
    });

    test('countNewArticles correctly counts articles not in DB', () async {
      final articles = [
        NewsArticle(
          title: 'A1',
          url: 'u1',
          source: 's',
          publishedAt: DateTime.now(),
        ),
        NewsArticle(
          title: 'A2',
          url: 'u2',
          source: 's',
          publishedAt: DateTime.now(),
        ),
      ];

      // Add one to DB using proper Drift companion
      await db
          .into(db.articles)
          .insert(
            ArticlesCompanion.insert(
              id: NewsRepositorySyncHelper.articleIdFromUrl(articles[0].url),
              title: articles[0].title,
              url: articles[0].url,
              source: articles[0].source,
              publishedAt: articles[0].publishedAt,
            ),
          );

      final newCount = await repository.countNewArticles(articles);
      expect(newCount, 1);
    });
  });
}
