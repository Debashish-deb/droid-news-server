import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/presentation/features/common/widgets/webview_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NewsArticle buildArticle() {
    return NewsArticle(
      title: 'Sample article',
      description: 'Sample description',
      url: 'https://example.com',
      source: 'Example',
      publishedAt: DateTime(2026, 3, 25),
    );
  }

  Widget buildHeader({required bool showTtsButton}) {
    return MaterialApp(
      home: Scaffold(
        body: WebHeader(
          article: buildArticle(),
          progressNotifier: ValueNotifier<double>(0.3),
          reduceEffects: false,
          cs: const ColorScheme.light(),
          isReader: showTtsButton,
          onBack: () {},
          onReaderToggle: () {},
          onTtsToggle: () {},
          ttsIcon: Icons.headset_rounded,
          onShare: () {},
          onTtsSettings: () {},
          showTtsButton: showTtsButton,
        ),
      ),
    );
  }

  testWidgets('hides TTS controls when showTtsButton is false', (tester) async {
    await tester.pumpWidget(buildHeader(showTtsButton: false));

    expect(find.byIcon(Icons.headset_rounded), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });

  testWidgets('shows TTS controls when showTtsButton is true', (tester) async {
    await tester.pumpWidget(buildHeader(showTtsButton: true));

    expect(find.byIcon(Icons.headset_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });
}
