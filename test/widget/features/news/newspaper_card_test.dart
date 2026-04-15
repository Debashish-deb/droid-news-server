import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:bdnewsreader/presentation/features/news/widgets/newspaper_card.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/infrastructure/repositories/settings_repository_impl.dart';
import 'package:bdnewsreader/application/sync/sync_orchestrator.dart';
import 'package:bdnewsreader/domain/repositories/premium_repository.dart';
import 'package:mockito/mockito.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NewspaperCard Widget', () {
    late Map<String, dynamic> testNews;
    late SharedPreferences prefs;
    late SyncOrchestrator syncOrchestrator;
    late _MockPremiumRepository mockPremiumRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_mode': 'light',
        'language_code': 'en',
      });
      prefs = await SharedPreferences.getInstance();

      syncOrchestrator = _MockSyncOrchestrator();
      mockPremiumRepository = _MockPremiumRepository();

      testNews = {
        'id': '123',
        'name': 'Breaking News: Important Event',
        'title': 'Breaking News: Important Event',
        'description': 'This is a test news article for unit testing',
        'url': 'https://example.com/breaking-news',
        'link': 'https://example.com/breaking-news',
        'pubDate': DateTime.now().toIso8601String(),
        'published': DateTime.now().toIso8601String(),
        'contact': {'website': 'https://example.com/breaking-news'},
        'enclosure': {'url': 'https://example.com/image.jpg'},
      };
    });

    Widget wrapWithProviders(Widget child) {
      return ProviderScope(
        overrides: [
          themeProvider.overrideWith(
            (ref) => ThemeNotifier(
              SettingsRepositoryImpl(prefs),
              syncOrchestrator,
              mockPremiumRepository,
            ),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('TC-WIDGET-021: NewspaperCard displays and renders correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            mode: AppThemeMode.system,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewspaperCard), findsOneWidget);
    });

    testWidgets('TC-WIDGET-022: No legacy favorite button is rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            mode: AppThemeMode.system,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewspaperCard), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });

    testWidgets('TC-WIDGET-023: Card tap invokes publisher handler', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            mode: AppThemeMode.system,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NewspaperCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('TC-WIDGET-024: No legacy share button is rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            mode: AppThemeMode.system,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewspaperCard), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing);
    });

    testWidgets('TC-WIDGET-025: NewspaperCard can render in a list', (
      tester,
    ) async {
      final newsList = List.generate(
        5,
        (i) => {
          'id': '$i',
          'name': 'News Item $i',
          'title': 'News Item $i',
          'description': 'Description for news item $i',
          'url': 'https://example.com/$i',
          'link': 'https://example.com/$i',
          'pubDate': DateTime.now().toIso8601String(),
          'published': DateTime.now().toIso8601String(),
          'contact': {'website': 'https://example.com/$i'},
        },
      );

      await tester.pumpWidget(
        wrapWithProviders(
          SizedBox(
            width: 400,
            height: 800,
            child: ListView.builder(
              itemCount: newsList.length,
              itemBuilder: (context, index) => NewspaperCard(
                news: newsList[index],
                mode: AppThemeMode.system,
                isFavorite: false,
                onFavoriteToggle: () {},
                searchQuery: '',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewspaperCard), findsWidgets);
    });

    testWidgets(
      'TC-WIDGET-026: lightweight NewspaperCard renders quick layout without action icons',
      (tester) async {
        await tester.pumpWidget(
          wrapWithProviders(
            NewspaperCard(
              news: testNews,
              mode: AppThemeMode.system,
              isFavorite: false,
              onFavoriteToggle: () {},
              searchQuery: '',
              lightweightMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Breaking News: Important Event'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        expect(find.byIcon(Icons.share), findsNothing);
      },
    );
  });
}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class _MockPremiumRepository extends Mock implements PremiumRepository {
  @override
  Stream<bool> get premiumStatusStream => Stream.value(false);
}
