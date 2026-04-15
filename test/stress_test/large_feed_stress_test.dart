import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/features/home/home_screen.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import 'package:bdnewsreader/infrastructure/ai/engine/quantized_tfidf_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';

class MockNewsRepository extends Mock implements NewsRepository {}
class MockRankingPipeline extends Mock implements RankingPipeline {}
class MockQuantizedTfIdfEngine extends Mock implements QuantizedTfIdfEngine {}

void main() {
  late MockNewsRepository mockRepo;
  late MockRankingPipeline mockPipeline;
  late MockQuantizedTfIdfEngine mockEngine;

  setUpAll(() {
    registerFallbackValue(const Locale('en'));
  });

  setUp(() {
    mockRepo = MockNewsRepository();
    mockPipeline = MockRankingPipeline();
    mockEngine = MockQuantizedTfIdfEngine();

    // Default mock behavior
    when(() => mockPipeline.rank(any())).thenAnswer((i) async => i.positionalArguments[0] as List<NewsArticle>);
    when(() => mockRepo.syncNews(
      locale: any(named: 'locale'), 
      force: any(named: 'force'), 
      category: any(named: 'category'),
    )).thenAnswer((_) async => const Right(0));
    when(() => mockRepo.getArticlesByCategory(
      any(),
      page: any(named: 'page'),
      limit: any(named: 'limit'),
      language: any(named: 'language'),
    )).thenAnswer((_) async => const Right([]));
  });

  testWidgets('Large Feed Stress Test - 5000 Articles', (WidgetTester tester) async {
    final List<NewsArticle> largeDataset = List.generate(5000, (i) => NewsArticle(
      title: 'Stress Test Article $i',
      description: 'Long description for article $i. ' * 5,
      url: 'https://stress.test/$i',
      source: 'StressSource',
      publishedAt: DateTime.now().subtract(Duration(minutes: i)),
      category: 'national',
    ));

    when(() => mockRepo.watchArticles(any(), any())).thenAnswer((_) => Stream.value(largeDataset));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newsProvider.overrideWith((ref) => NewsNotifier(
            newsRepository: mockRepo,
            rankingPipeline: mockPipeline,
            tfIdfEngine: mockEngine,
          )),
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

    // Initial load call
    await tester.pump(); // Trigger build
    await tester.pumpAndSettle(); // Wait for stream and animation

    expect(find.byType(CustomScrollView), findsOneWidget);

    // Simulate intense scrolling to check for jank/crashes in the widget tree
    final listFinder = find.byType(CustomScrollView);
      // 2. Wait for UI to settle (Home screen and List should be ready)
      await tester.pumpAndSettle();

      // 3. Kick off rapid scroll
      print('🚀 Starting rapid scroll stress test...');
      expect(listFinder, findsOneWidget, reason: 'Feedback: ListView must be visible to start stress test');
      
      for (int i = 0; i < 50; i++) {
        await tester.drag(listFinder, const Offset(0, -500));
        await tester.pump(); // Immediate feedback
      }

    await tester.drag(listFinder, const Offset(0.0, -10000.0));
    await tester.pumpAndSettle();

    debugPrint('✅ Stress test completed without widget exceptions.');
  });
}
