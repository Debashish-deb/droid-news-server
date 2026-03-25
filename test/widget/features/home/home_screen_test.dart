import 'dart:io'; 
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';

import 'package:bdnewsreader/presentation/features/home/home_screen.dart';
import 'package:bdnewsreader/presentation/features/home/widgets/news_card.dart';
import "package:bdnewsreader/domain/entities/news_article.dart";
import 'package:bdnewsreader/infrastructure/services/news/rss_service.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:bdnewsreader/presentation/providers/language_providers.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/presentation/providers/premium_providers.dart';
import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart';
import 'package:bdnewsreader/presentation/providers/favorites_providers.dart';
import 'package:bdnewsreader/presentation/providers/tab_providers.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:bdnewsreader/infrastructure/persistence/models/news_article.dart'; // For Adapter
import 'package:bdnewsreader/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart'; // Import RankingPipeline
import 'package:bdnewsreader/infrastructure/ai/engine/quantized_tfidf_engine.dart';

// Helper to generate mock
@GenerateNiceMocks([MockSpec<RankingPipeline>()])
import 'home_screen_test.mocks.dart';

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
  Stream<List<NewsArticle>> watchArticles(String category, Locale locale) async* {
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

void main() {
  setUpAll(() async {
    // Mock Path Provider for Hive.initFlutter
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    // Initialize Hive manually in temp dir
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(NewsArticleModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('HomeScreen renders news feed when loaded', (WidgetTester tester) async {
    final fakeRssService = FakeRssService();
    final testArticle = NewsArticle(
      source: 'Test Source',
      title: 'Test Title',
      description: 'Test Description', 
      url: 'https://example.com',
      imageUrl: 'https://example.com/image.png',
      publishedAt: DateTime.now(),
    );
    fakeRssService.setNews([testArticle]);

    // Mock Ranking Pipeline
    final mockRankingPipeline = MockRankingPipeline();
    // Use when(...) to return articles as-is (wrapped in Future)
    when(mockRankingPipeline.rank(any)).thenAnswer((invocation) => Future.value(invocation.positionalArguments[0] as List<NewsArticle>));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override newsProvider properly
          newsProvider.overrideWith((ref) => NewsNotifier(
            newsRepository: FakeNewsRepository(rssService: fakeRssService),
            rankingPipeline: mockRankingPipeline,
            tfIdfEngine: QuantizedTfIdfEngine(),
          )),
          
          currentThemeModeProvider.overrideWithValue(AppThemeMode.light),
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

    await tester.pump(const Duration(seconds: 2));

    // Debug output if fails
    if (find.text('Test Title').evaluate().isEmpty) {
       debugPrint('❌ Test Title not found!');
    }

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.byType(NewsCard), findsOneWidget);
  });
}
