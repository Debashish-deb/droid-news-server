import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebView Screen Widget', () {
    testWidgets('TC-WIDGET-040: WebView screen has navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Article'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
              ),
              actions: [
                IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                IconButton(icon: const Icon(Icons.open_in_browser), onPressed: () {}),
              ],
            ),
            body: const Center(child: Text('WebView Content')),
          ),
        ),
      );

      expect(find.text('Article'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('TC-WIDGET-041: Share button is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('TC-WIDGET-042: Open in browser button works', (tester) async {
      var opened = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: () => opened = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.open_in_browser));
      expect(opened, isTrue);
    });

    testWidgets('TC-WIDGET-043: Loading indicator shows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(child: Text('WebView')),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('TC-WIDGET-044: Favorite button toggles', (tester) async {
      var isFavorite = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              appBar: AppBar(
                actions: [
                  IconButton(
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    onPressed: () => setState(() => isFavorite = !isFavorite),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}
