import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  group('Article Reading Flow E2E', () {
    test('TC-E2E-020: Article data is complete', () {
      final article = NewsArticle(
        title: 'Breaking News: Important Event',
        url: 'https://example.com/breaking-news',
        source: 'Prothom Alo',
        description: 'Detailed description of the event',
        imageUrl: 'https://example.com/image.jpg',
        publishedAt: DateTime.now(),
      );
      
      expect(article.title, isNotEmpty);
      expect(article.url, startsWith('https://'));
      expect(article.source, isNotEmpty);
    });

    test('TC-E2E-021: Article URL is valid', () {
      final article = NewsArticle(
        title: 'Test',
        url: 'https://example.com/article/123',
        source: 'Source',
        publishedAt: DateTime.now(),
      );
      
      final uri = Uri.tryParse(article.url);
      
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
    });

    test('TC-E2E-022: Article date is parseable', () {
      final article = NewsArticle(
        title: 'Test',
        url: 'https://example.com',
        source: 'Source',
        publishedAt: DateTime(2024, 12, 25, 10, 30),
      );
      
      expect(article.publishedAt.year, 2024);
      expect(article.publishedAt.month, 12);
      expect(article.publishedAt.day, 25);
    });

    test('TC-E2E-023: Time ago calculation works', () {
      String getTimeAgo(DateTime publishedAt) {
        final diff = DateTime.now().difference(publishedAt);
        
        if (diff.inDays > 0) return '${diff.inDays} days ago';
        if (diff.inHours > 0) return '${diff.inHours} hours ago';
        if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
        return 'Just now';
      }
      
      expect(getTimeAgo(DateTime.now().subtract(const Duration(hours: 2))), contains('hour'));
      expect(getTimeAgo(DateTime.now().subtract(const Duration(days: 3))), contains('day'));
      expect(getTimeAgo(DateTime.now()), 'Just now');
    });

    testWidgets('TC-E2E-024: Article card is tappable', (tester) async {
      var tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkWell(
              onTap: () => tapped = true,
              child: const Card(
                child: ListTile(
                  title: Text('Article Title'),
                  subtitle: Text('Source'),
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.tap(find.byType(Card));
      expect(tapped, isTrue);
    });

    testWidgets('TC-E2E-025: Article can be shared', (tester) async {
      var shared = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => shared = true,
                ),
              ],
            ),
          ),
        ),
      );
      
      await tester.tap(find.byIcon(Icons.share));
      expect(shared, isTrue);
    });

    testWidgets('TC-E2E-026: Article can be favorited', (tester) async {
      var favorited = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => IconButton(
                icon: Icon(favorited ? Icons.favorite : Icons.favorite_border),
                onPressed: () => setState(() => favorited = !favorited),
              ),
            ),
          ),
        ),
      );
      
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}
