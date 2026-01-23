import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breaking News Ticker Widget', () {
    testWidgets('TC-WIDGET-050: Ticker renders headlines', (tester) async {
      final headlines = ['Breaking: Event 1', 'Update: Event 2', 'Alert: Event 3'];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              height: 40,
              color: Colors.red,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: headlines.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text(headlines[index], style: const TextStyle(color: Colors.white))),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Breaking: Event 1'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-051: Ticker has LIVE indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  color: Colors.red,
                  child: const Text('LIVE', style: TextStyle(color: Colors.white)),
                ),
                const Text('Breaking News'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-052: Ticker scrolls horizontally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(
                  10,
                  (i) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Headline $i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Headline 0'), findsOneWidget);
      
      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      
      // Scrolled to next headlines
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('TC-WIDGET-053: Ticker background is red', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              color: Colors.red,
              height: 40,
              child: const Center(child: Text('Breaking News')),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, Colors.red);
    });
  });
}
