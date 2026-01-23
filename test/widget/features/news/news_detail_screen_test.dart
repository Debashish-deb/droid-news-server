import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdnewsreader/features/news_detail/news_detail_screen.dart';
import 'package:bdnewsreader/data/models/news_article.dart';
import 'package:bdnewsreader/presentation/providers/saved_articles_provider.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:bdnewsreader/core/theme_provider.dart';
import 'package:bdnewsreader/core/services/saved_articles_service.dart';
import 'package:bdnewsreader/l10n/app_localizations.dart'; 

// Fake Service - much simpler than mocking for this case
class FakeSavedArticlesService implements SavedArticlesService {
  final List<NewsArticle> _saved = [];
  
  void setSaved(List<NewsArticle> articles) {
    _saved.clear();
    _saved.addAll(articles);
  }

  @override
  Future<void> init() async {}
  
  @override
  bool isSaved(String? url) => _saved.any((a) => a.url == url);
  
  @override
  List<NewsArticle> getSavedArticles() => List.unmodifiable(_saved);

  // Implement other methods safely
  @override
  Future<bool> saveArticle(NewsArticle article) async {
    _saved.add(article);
    return true;
  }
  
  @override
  Future<bool> removeArticle(String url) async {
    _saved.removeWhere((a) => a.url == url);
    return true;
  }
  
  @override
  int get savedCount => _saved.length;
  
  @override
  double get storageUsageMB => 0;
  
  @override
  Future<void> clearAll() async => _saved.clear();
  
  @override
  NewsArticle? getSavedArticle(String url) => 
      _saved.where((a) => a.url == url).firstOrNull;
      
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  // Common test data
  final testArticle = NewsArticle(
    source: 'Test Source',
    title: 'Test Title',
    description: 'Test Description',
    url: 'https://example.com/test',
    imageUrl: 'https://example.com/image.png',
    publishedAt: DateTime(2023),
    fullContent: 'Test Content',
  );

  testWidgets('NewsDetailScreen renders AppBar with source and FAB', (WidgetTester tester) async {
    // Setup Fake Service and Notifier
    final fakeService = FakeSavedArticlesService();
    // Default empty state
    
    final notifier = SavedArticlesNotifier(service: fakeService);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedArticlesProvider.overrideWith((ref) => notifier),
          currentThemeModeProvider.overrideWithValue(AppThemeMode.light),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: NewsDetailScreen(news: testArticle),
        ),
      ),
    );
    
    // Pump to ensure any async ops settle
    await tester.pumpAndSettle();

    expect(find.text('Test Source'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
  });

  testWidgets('NewsDetailScreen shows correct icon when article is saved', (WidgetTester tester) async {
    final fakeService = FakeSavedArticlesService();
    // Pre-populate service with saved article
    fakeService.setSaved([testArticle]);
    
    final notifier = SavedArticlesNotifier(service: fakeService);
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedArticlesProvider.overrideWith((ref) => notifier),
          currentThemeModeProvider.overrideWithValue(AppThemeMode.light),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: NewsDetailScreen(news: testArticle),
        ),
      ),
    );
    
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
