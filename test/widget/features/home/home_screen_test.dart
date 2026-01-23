import 'dart:io'; 
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:bdnewsreader/features/home/home_screen.dart';
import 'package:bdnewsreader/features/home/widgets/news_card.dart';
import 'package:bdnewsreader/data/models/news_article.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/repositories/news_repository.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:bdnewsreader/presentation/providers/language_providers.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:bdnewsreader/core/theme_provider.dart';
import 'package:bdnewsreader/presentation/providers/subscription_providers.dart';
import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart';
import 'package:bdnewsreader/core/services/favorites_providers.dart';
import 'package:bdnewsreader/presentation/providers/tab_providers.dart';
import 'package:bdnewsreader/l10n/app_localizations.dart';

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
    bool preferRss = false,
  }) async {
    return _news;
  }
}

void main() {
  setUpAll(() async {
    // Mock Path Provider for Hive.initFlutter
    // We need this because HomeScreen calls HiveService.init which calls Hive.initFlutter
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );

    // Initialize Hive manually in temp dir
    Hive.init(Directory.systemTemp.path);
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(NewsArticleAdapter());
    }
  });

  testWidgets('HomeScreen renders news feed when loaded', (WidgetTester tester) async {
    // Open the box expected by logic
    if (!Hive.isBoxOpen('latest')) {
       await Hive.openBox<NewsArticle>('latest');
       await Hive.openBox('latest_meta');
    }

    final fakeRssService = FakeRssService();
    final testArticle = NewsArticle(
      source: 'Test Source',
      title: 'Test Title',
      description: 'Test Description', 
      url: 'https://example.com',
      imageUrl: 'https://example.com/image.png',
      publishedAt: DateTime.now(),
      fullContent: 'Content',
    );
    fakeRssService.setNews([testArticle]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override newsProvider properly
          newsProvider.overrideWith((ref) => NewsNotifier(newsRepository: NewsRepository(rssService: fakeRssService))),
          
          currentThemeModeProvider.overrideWithValue(AppThemeMode.light),
          currentLocaleProvider.overrideWithValue(const Locale('en')),
          
          // Subscription & Settings
          isPremiumProvider.overrideWithValue(true), 
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
       debugPrint('Checking for errors...');
       final errorFind = find.textContaining('Error');
       if (errorFind.evaluate().isNotEmpty) {
          debugPrint('Found Error Text: ${errorFind.evaluate()}');
       }
       if (find.text('No articles found').evaluate().isNotEmpty) {
           debugPrint('Found Empty State Text: No articles found');
       }
    }

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.byType(NewsCard), findsOneWidget);
  });
}
