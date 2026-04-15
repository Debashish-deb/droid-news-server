import 'dart:io';

import 'package:bdnewsreader/application/ai/ranking/user_interest_service.dart';
import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/infrastructure/ai/engine/quantized_tfidf_engine.dart';
import 'package:bdnewsreader/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import 'package:bdnewsreader/infrastructure/persistence/models/news_article.dart';
import 'package:bdnewsreader/infrastructure/services/news/rss_service.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:bdnewsreader/presentation/features/home/home_screen.dart';
import 'package:bdnewsreader/presentation/features/home/widgets/news_card.dart';
import 'package:bdnewsreader/presentation/features/home/widgets/professional_header.dart';
import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart';
import 'package:bdnewsreader/presentation/providers/favorites_providers.dart';
import 'package:bdnewsreader/presentation/providers/language_providers.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:bdnewsreader/presentation/providers/premium_providers.dart';
import 'package:bdnewsreader/presentation/providers/tab_providers.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// Fake RssService
class FakeRssService extends Fake implements RssService {
  List<NewsArticle> _news = [];

  void setNews(List<NewsArticle> news) {
    _news = news;
  }

  @override
  Future<List<NewsArticle>> fetchNews({
    required String category,
    required Locale locale,
    BuildContext? context,
    Set<String>? disabledUrls,
    bool preferRss = false,
  }) async {
    return _news;
  }
}

List<NewsArticle> _buildArticles(int count) {
  return List<NewsArticle>.generate(
    count,
    (index) => NewsArticle(
      source: 'Test Source $index',
      title: 'Test Title $index',
      description: 'Test Description $index',
      url: 'https://example.com/$index',
      imageUrl: 'https://example.com/image_$index.png',
      publishedAt: DateTime.now().subtract(Duration(minutes: index)),
    ),
    growable: false,
  );
}

class FakeNewsRepository extends Fake implements NewsRepository {
  FakeNewsRepository({required this.rssService});
  final RssService rssService;

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getNewsFeed({
    required int page,
    required int limit,
    String? category,
    String? language,
  }) async {
    // We ignore language in fake for simplicity
    final news = await rssService.fetchNews(
      category: category ?? 'all',
      locale: const Locale('en'),
    );
    return Right(news);
  }

  // Also need to implement getArticlesByCategory as NewsNotifier uses it
  @override
  Future<Either<AppFailure, List<NewsArticle>>> getArticlesByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    String? language,
  }) async {
    final news = await rssService.fetchNews(
      category: category,
      locale: const Locale('en'),
    );
    return Right(news);
  }

  @override
  Stream<List<NewsArticle>> watchArticles(
    String category,
    Locale locale,
  ) async* {
    yield await rssService.fetchNews(category: category, locale: locale);
  }

  @override
  Future<Either<AppFailure, int>> syncNews({
    required Locale locale,
    bool force = false,
    String? category,
  }) async {
    return const Right(0);
  }
}

class _PassthroughRankingPipeline extends RankingPipeline {
  _PassthroughRankingPipeline(NewsRepository repository)
    : super(repository, UserInterestService.disabled(QuantizedTfIdfEngine()));

  @override
  Future<List<NewsArticle>> rank(
    List<NewsArticle> articles, {
    bool prioritizeBangladesh = false,
  }) async {
    return articles;
  }
}

void main() {
  setUpAll(() async {
    // Mock Path Provider for Hive.initFlutter
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return tempDir.path;
        });

    // Initialize Hive manually in temp dir
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NewsArticleModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('HomeScreen renders news feed when loaded', (
    WidgetTester tester,
  ) async {
    final fakeRssService = FakeRssService();
    final fakeRepository = FakeNewsRepository(rssService: fakeRssService);
    final notifier = NewsNotifier(
      newsRepository: fakeRepository,
      rankingPipeline: _PassthroughRankingPipeline(fakeRepository),
      tfIdfEngine: QuantizedTfIdfEngine(),
    );
    final testArticle = NewsArticle(
      source: 'Test Source',
      title: 'Test Title',
      description: 'Test Description',
      url: 'https://example.com',
      imageUrl: 'https://example.com/image.png',
      publishedAt: DateTime.now(),
    );
    fakeRssService.setNews([testArticle]);
    await notifier.loadNews(
      'latest',
      const Locale('en'),
      syncWithNetwork: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override newsProvider properly
          newsProvider.overrideWith((ref) => notifier),

          currentThemeModeProvider.overrideWithValue(AppThemeMode.system),
          currentLocaleProvider.overrideWithValue(const Locale('en')),

          // Subscription & Settings
          isPremiumProvider.overrideWith((ref) => Stream<bool>.value(true)),
          dataSaverProvider.overrideWithValue(false),

          // Theme & Other
          glassColorProvider.overrideWithValue(Colors.black),
          borderColorProvider.overrideWithValue(Colors.transparent),
          favoritesCountProvider.overrideWithValue(0),

          // Tabs
          currentTabIndexProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Debug output if fails
    if (find.text('Test Title').evaluate().isEmpty) {
      debugPrint('❌ Test Title not found!');
    }

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.byType(NewsCard), findsOneWidget);
  });

  testWidgets(
    'HomeScreen reveals latest articles progressively on first load',
    (WidgetTester tester) async {
      final fakeRssService = FakeRssService();
      final fakeRepository = FakeNewsRepository(rssService: fakeRssService);
      final notifier = NewsNotifier(
        newsRepository: fakeRepository,
        rankingPipeline: _PassthroughRankingPipeline(fakeRepository),
        tfIdfEngine: QuantizedTfIdfEngine(),
      );
      fakeRssService.setNews(_buildArticles(12));
      await notifier.loadNews(
        'latest',
        const Locale('en'),
        syncWithNetwork: false,
      );

      await tester.binding.setSurfaceSize(const Size(1080, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newsProvider.overrideWith((ref) => notifier),
            currentThemeModeProvider.overrideWithValue(AppThemeMode.system),
            currentLocaleProvider.overrideWithValue(const Locale('en')),
            isPremiumProvider.overrideWith((ref) => Stream<bool>.value(true)),
            dataSaverProvider.overrideWithValue(false),
            glassColorProvider.overrideWithValue(Colors.black),
            borderColorProvider.overrideWithValue(Colors.transparent),
            favoritesCountProvider.overrideWithValue(0),
            currentTabIndexProvider.overrideWithValue(0),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ProfessionalHeader),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 900));

      expect(
        find.descendant(
          of: find.byType(ProfessionalHeader),
          matching: find.text('12'),
        ),
        findsOneWidget,
      );
    },
  );
}
