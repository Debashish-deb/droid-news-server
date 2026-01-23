import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdnewsreader/core/theme_provider.dart';
import 'package:bdnewsreader/features/news/widgets/newspaper_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NewspaperCard Widget', () {
    late Map<String, dynamic> testNews;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_mode': 'light',
        'language_code': 'en',
      });
      prefs = await SharedPreferences.getInstance();
      
      testNews = {
        'id': '123',
        'name': 'Breaking News: Important Event',
        'title': 'Breaking News: Important Event',
        'description': 'This is a test news article for unit testing',
        'url': 'https://example.com/breaking-news',
        'link': 'https://example.com/breaking-news',
        'pubDate': DateTime.now().toIso8601String(),
        'published': DateTime.now().toIso8601String(),
        'contact': {
          'website': 'https://example.com/breaking-news',
        },
        'enclosure': {
          'url': 'https://example.com/image.jpg',
        },
      };
    });

    Widget wrapWithProviders(Widget child) {
      return ProviderScope(
        child: MaterialApp(
          home: provider.ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(prefs),
            child: Scaffold(body: child),
          ),
        ),
      );
    }

    testWidgets('TC-WIDGET-021: NewspaperCard displays and renders correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewspaperCard), findsOneWidget);
    });

    testWidgets('TC-WIDGET-022: Favorite button is visible', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Favorite icon should be present
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('TC-WIDGET-023: Favorite button toggles state', (tester) async {
      var isFavorite = false;
      
      await tester.pumpWidget(
        wrapWithProviders(
          StatefulBuilder(
            builder: (context, setState) => NewspaperCard(
              news: testNews,
              isFavorite: isFavorite,
              onFavoriteToggle: () => setState(() => isFavorite = !isFavorite),
              searchQuery: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the favorite icon
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      
      // Tap it
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      
      // Should now show filled heart
      expect(isFavorite, isTrue);
    });

    testWidgets('TC-WIDGET-024: Share button is present', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('TC-WIDGET-025: NewspaperCard can render in a list', (tester) async {
      final newsList = List.generate(5, (i) => {
        'id': '$i',
        'name': 'News Item $i',
        'title': 'News Item $i',
        'description': 'Description for news item $i',
        'url': 'https://example.com/$i',
        'link': 'https://example.com/$i',
        'pubDate': DateTime.now().toIso8601String(),
        'published': DateTime.now().toIso8601String(),
        'contact': {
          'website': 'https://example.com/$i',
        },
      });

      await tester.pumpWidget(
        wrapWithProviders(
          SizedBox(
            width: 400,
            height: 800,
            child: ListView.builder(
              itemCount: newsList.length,
              itemBuilder: (context, index) => NewspaperCard(
                news: newsList[index],
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
  });
}
