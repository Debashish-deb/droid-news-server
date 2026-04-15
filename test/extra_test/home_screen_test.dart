import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/features/home/home_screen.dart';
import 'package:bdnewsreader/presentation/features/home/widgets/news_feed_skeleton.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/presentation/widgets/error_widget.dart';
import 'package:bdnewsreader/core/di/providers.dart';

import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import 'package:bdnewsreader/infrastructure/ai/engine/quantized_tfidf_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNewsRepository extends Mock implements NewsRepository {}

class MockRankingPipeline extends Mock implements RankingPipeline {}

class MockTfIdfEngine extends Mock implements QuantizedTfIdfEngine {}

class NewsLoadInvocation {
  const NewsLoadInvocation({
    required this.category,
    required this.force,
    required this.syncWithNetwork,
  });

  final String category;
  final bool force;
  final bool syncWithNetwork;
}

class NewsNotifierMock extends NewsNotifier {
  NewsNotifierMock({
    Map<String, bool>? loading,
    Map<String, List<NewsArticle>>? articles,
    Map<String, String?>? errors,
  }) : super(
         newsRepository: MockNewsRepository(),
         rankingPipeline: MockRankingPipeline(),
         tfIdfEngine: MockTfIdfEngine(),
       ) {
    state = NewsState(
      loading:
          loading ??
          {
            'national': false,
            'international': false,
            'sports': false,
            'entertainment': false,
          },
      articles: articles ?? {},
      errors: errors ?? {},
    );
  }

  void setLoading(String category, bool isLoading) {
    final nextLoading = Map<String, bool>.from(state.loading);
    nextLoading[category] = isLoading;
    state = state.copyWith(loading: nextLoading);
  }

  void setLoaded(String category, List<NewsArticle> articles) {
    final nextArticles = Map<String, List<NewsArticle>>.from(state.articles);
    nextArticles[category] = articles;

    final nextLoading = Map<String, bool>.from(state.loading);
    nextLoading[category] = false;

    state = state.copyWith(articles: nextArticles, loading: nextLoading);
  }

  void setError(String category, String error) {
    final nextErrors = Map<String, String?>.from(state.errors);
    nextErrors[category] = error;

    final nextLoading = Map<String, bool>.from(state.loading);
    nextLoading[category] = false;

    state = state.copyWith(errors: nextErrors, loading: nextLoading);
  }

  @override
  Future<void> loadNews(
    String category,
    Locale locale, {
    bool force = false,
    bool syncWithNetwork = true,
  }) async {}
}

class RecordingNewsNotifier extends NewsNotifierMock {
  RecordingNewsNotifier({super.loading, super.articles, super.errors});

  final List<NewsLoadInvocation> loadCalls = <NewsLoadInvocation>[];

  @override
  Future<void> loadNews(
    String category,
    Locale locale, {
    bool force = false,
    bool syncWithNetwork = true,
  }) async {
    loadCalls.add(
      NewsLoadInvocation(
        category: category,
        force: force,
        syncWithNetwork: syncWithNetwork,
      ),
    );
  }
}

void main() {
  group('Home Screen State Transitions', () {
    testWidgets('should show skeleton when loading takes time', (
      WidgetTester tester,
    ) async {
      final notifier = NewsNotifierMock(
        loading: {'latest': true},
        articles: {'latest': []},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newsProvider.overrideWith((ref) => notifier as NewsNotifier),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('bn')],
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(NewsFeedSkeleton), findsOneWidget);

      notifier.setLoaded('latest', []);
      await tester.pump();

      expect(find.byType(NewsFeedSkeleton), findsNothing);
      expect(find.text('No Articles Found'), findsOneWidget);
    });

    testWidgets('should handle error state with retry button', (
      WidgetTester tester,
    ) async {
      final notifier = NewsNotifierMock(
        loading: {'latest': false},
        articles: {'latest': []},
        errors: {'latest': 'Network error'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newsProvider.overrideWith((ref) => notifier as NewsNotifier),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('bn')],
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ErrorDisplay), findsOneWidget);
    });

    testWidgets(
      'should not force latest network sync during initial startup window',
      (WidgetTester tester) async {
        final notifier = RecordingNewsNotifier(
          loading: {'latest': false},
          articles: {'latest': []},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              newsProvider.overrideWith((ref) => notifier as NewsNotifier),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [Locale('en'), Locale('bn')],
              home: HomeScreen(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 1200));

        expect(
          notifier.loadCalls.any(
            (call) => call.category == 'latest' && call.syncWithNetwork,
          ),
          isFalse,
        );
        expect(
          notifier.loadCalls.any(
            (call) => call.category == 'latest' && call.force,
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'should keep startup work on trending when trending is the saved category',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'selected_home_category': 'trending',
        });
        final prefs = await SharedPreferences.getInstance();
        final notifier = RecordingNewsNotifier(
          loading: {'latest': false, 'trending': false},
          articles: {'latest': [], 'trending': []},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              newsProvider.overrideWith((ref) => notifier as NewsNotifier),
              sharedPreferencesProvider.overrideWith((ref) => prefs),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [Locale('en'), Locale('bn')],
              home: HomeScreen(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 1200));

        expect(
          notifier.loadCalls.any((call) => call.category == 'latest'),
          isFalse,
        );

        await tester.pump(const Duration(seconds: 10));

        expect(
          notifier.loadCalls.any((call) => call.category == 'latest'),
          isFalse,
        );
      },
    );
  });
}
