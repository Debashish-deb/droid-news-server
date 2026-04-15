import 'dart:ui';

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
        prefs: mockPrefs,
      );

      when(mockPrefs.getString(any)).thenReturn('en');
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getStringList(any)).thenReturn(null);
      when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
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

    test('syncNews treats fresh TTL cache skip as success', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      when(mockPrefs.getInt('news_sync_ts_en_latest')).thenReturn(now);

      final result = await repository.syncNews(
        locale: const Locale('en'),
        category: 'latest',
      );

      expect(result.isRight(), isTrue);
      expect(result.getOrElse(-1), 0);
      verifyNever(
        mockRss.fetchNews(
          category: anyNamed('category'),
          locale: anyNamed('locale'),
        ),
      );
    });

    test('syncNews forwards disabled source URLs to RSS fetch', () async {
      when(
        mockPrefs.getStringList('disabled_news_sources'),
      ).thenReturn(<String>['https://www.kalerkantho.com/rss.xml']);
      when(mockPrefs.getInt('news_sync_ts_en_latest')).thenReturn(null);

      when(
        mockRss.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
          disabledUrls: anyNamed('disabledUrls'),
        ),
      ).thenAnswer((_) async => <NewsArticle>[]);
      when(
        mockRss.wasLastFetchSuccessful(category: 'latest', language: 'en'),
      ).thenReturn(true);

      final result = await repository.syncNews(
        locale: const Locale('en'),
        category: 'latest',
      );

      expect(result.isRight(), isTrue);
      verify(
        mockRss.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
          disabledUrls: argThat(
            equals(<String>{'https://www.kalerkantho.com/rss.xml'}),
            named: 'disabledUrls',
          ),
        ),
      ).called(1);
    });

    test(
      'watchArticles hides cached rows from disabled source hosts',
      () async {
        when(
          mockPrefs.getStringList('disabled_news_sources'),
        ).thenReturn(<String>['https://www.kalerkantho.com/rss.xml']);

        final now = DateTime.now();
        await db
            .into(db.articles)
            .insert(
              ArticlesCompanion.insert(
                id: 'kaler-1',
                title: 'Blocked Source News',
                url: 'https://www.kalerkantho.com/news/1',
                source: 'Kaler Kantha',
                publishedAt: now,
              ),
            );
        await db
            .into(db.articles)
            .insert(
              ArticlesCompanion.insert(
                id: 'other-1',
                title: 'Visible Source News',
                url: 'https://www.thedailystar.net/news/1',
                source: 'The Daily Star',
                publishedAt: now.subtract(const Duration(minutes: 1)),
              ),
            );

        final rows = await repository
            .watchArticles('latest', const Locale('en'))
            .first;

        expect(rows, hasLength(1));
        expect(rows.first.source, 'The Daily Star');
        expect(rows.first.url, contains('thedailystar.net'));
      },
    );

    test('watchArticles latest stream is not capped to 20 items', () async {
      when(mockPrefs.getStringList('disabled_news_sources')).thenReturn(null);

      final now = DateTime.now();
      for (var i = 0; i < 25; i++) {
        await db
            .into(db.articles)
            .insert(
              ArticlesCompanion.insert(
                id: 'latest-$i',
                title: 'Latest $i',
                url: 'https://example.com/latest/$i',
                source: 'Example Source',
                publishedAt: now.subtract(Duration(minutes: i)),
              ),
            );
      }

      final rows = await repository
          .watchArticles('latest', const Locale('en'))
          .first;

      expect(rows.length, 25);
    });
  });
}
