import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/domain/entities/news_thread.dart';
import 'package:bdnewsreader/presentation/features/news/widgets/news_thread_card.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  testWidgets('NewsThreadCard renders main article and 3D elements', (tester) async {
    // Arrange
    final article = NewsArticle(
      url: 'url',
      title: 'Main Story Title',
      publishedAt: DateTime.now(),
      source: 'CNN',
      imageUrl: 'http://example.com/image.jpg',
    );
    final thread = NewsThread(
      id: '1',
      mainArticle: article,
      relatedArticles: [
        NewsArticle(url: 'r1', title: 'Related 1', publishedAt: DateTime.now(), source: 'BBC'),
        NewsArticle(url: 'r2', title: 'Related 2', publishedAt: DateTime.now(), source: 'Reuters'),
      ],
    );

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NewsThreadCard(
            thread: thread,
            onTap: () {},
          ),
        ),
      ),
    );

    // Assert
    expect(find.text('Main Story Title'), findsOneWidget);
    expect(find.text('CNN'), findsOneWidget);
    expect(find.text('MORE PERSPECTIVES'), findsOneWidget); // 3D card layer
    expect(find.text('BBC'), findsOneWidget);
    
    // Check for Shadow/Decoration (Simple check that Container exists)
    expect(find.byType(Container), findsWidgets);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
